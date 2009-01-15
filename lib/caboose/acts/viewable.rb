module Caboose #:nodoc:
  module Acts #:nodoc:
    # Overrides some basic methods for the current model so that calling #destroy sets a 'published_at' field to the current timestamp.
    # This assumes the table has a published_at date/time field.  Most normal model operations will work, but there will be some oddities.
    #
    #   class Widget < ActiveRecord::Base
    #     acts_as_viewable
    #   end
    #
    #   Widget.find(:all)
    #   # SELECT * FROM widgets WHERE widgets.published_at IS NULL
    #
    #   Widget.find(:first, :conditions => ['title = ?', 'test'], :order => 'title')
    #   # SELECT * FROM widgets WHERE widgets.published_at IS NULL AND title = 'test' ORDER BY title LIMIT 1
    #
    #   Widget.find_with_published(:all)
    #   # SELECT * FROM widgets
    #
    #   Widget.find_only_published(:all)
    #   # SELECT * FROM widgets WHERE widgets.published_at IS NOT NULL
    #
    #   Widget.find_with_published(1).published?
    #   # Returns true if the record was previously destroyed, false if not 
    #
    #   Widget.count
    #   # SELECT COUNT(*) FROM widgets WHERE widgets.published_at IS NULL
    #
    #   Widget.count ['title = ?', 'test']
    #   # SELECT COUNT(*) FROM widgets WHERE widgets.published_at IS NULL AND title = 'test'
    #
    #   Widget.count_with_published
    #   # SELECT COUNT(*) FROM widgets
    #
    #   Widget.count_only_published
    #   # SELECT COUNT(*) FROM widgets WHERE widgets.published_at IS NOT NULL
    #
    #   Widget.delete_all
    #   # UPDATE widgets SET published_at = '2005-09-17 17:46:36'
    #
    #   Widget.delete_all!
    #   # DELETE FROM widgets
    #
    #   @widget.destroy
    #   # UPDATE widgets SET published_at = '2005-09-17 17:46:36' WHERE id = 1
    #
    #   @widget.destroy!
    #   # DELETE FROM widgets WHERE id = 1
    # 
    module Viewable
      def self.included(base) # :nodoc:
        base.extend ClassMethods
      end

      module ClassMethods
        def acts_as_viewable(options = {})
          unless viewable? # don't let AR call this twice
            cattr_accessor :published_attribute
            self.published_attribute = options[:with] || :published_at
            alias_method :destroy_without_callbacks!, :destroy_without_callbacks
            class << self
              alias_method :find_every_with_published,    :find_every
              alias_method :calculate_with_published,     :calculate
              alias_method :delete_all!,                :delete_all
            end
          end
          include InstanceMethods
        end

        def viewable?
          self.included_modules.include?(InstanceMethods)
        end
      end

      module InstanceMethods #:nodoc:
        def self.included(base) # :nodoc:
          base.extend ClassMethods
        end

        module ClassMethods
          def find_with_unpublished(*args)
            options = args.extract_options!
            validate_find_options(options)
            set_readonly_option!(options)
            options[:with_published] = true # yuck!

            case args.first
              when :first then find_initial(options)
              when :all   then find_every(options)
              else             find_from_ids(args, options)
            end
          end

          def find_only_unpublished(*args)
            options = args.extract_options!
            validate_find_options(options)
            set_readonly_option!(options)
            options[:only_published] = true # yuck!

            case args.first
              when :first then find_initial(options)
              when :all   then find_every(options)
              else             find_from_ids(args, options)
            end
          end

          def exists?(*args)
            with_published_scope { exists_with_published?(*args) }
          end

          def exists_only_published?(*args)
            with_only_published_scope { exists_with_published?(*args) }
          end

          def count_with_published(*args)
            calculate_with_published(:count, *construct_count_options_from_args(*args))
          end

          def count_only_published(*args)
            with_only_published_scope { count_with_published(*args) }
          end

          def count(*args)
            with_published_scope { count_with_published(*args) }
          end

          def calculate(*args)
            with_published_scope { calculate_with_published(*args) }
          end

          def delete_all(conditions = nil)
            self.update_all ["#{self.published_attribute} = ?", current_time], conditions
          end

          protected
            def current_time
              default_timezone == :utc ? Time.now.utc : Time.now
            end

            def with_published_scope(&block)
              with_scope({:find => { :conditions => ["#{table_name}.#{published_attribute} IS NULL OR #{table_name}.#{published_attribute} < ?", current_time] } }, :merge, &block)
            end

            def with_only_published_scope(&block)
              with_scope({:find => { :conditions => ["#{table_name}.#{published_attribute} IS NOT NULL AND #{table_name}.#{published_attribute} >= ?", current_time] } }, :merge, &block)
            end

          private
            # all find calls lead here
            def find_every(options)
              options.delete(:with_published) ? 
                find_every_with_published(options) :
                options.delete(:only_published) ? 
                  with_only_published_scope { find_every_with_published(options) } :
                  with_published_scope { find_every_with_published(options) }
            end
        end

        def destroy_without_callbacks
          unless new_record?
            self.class.update_all self.class.send(:sanitize_sql, ["#{self.class.published_attribute} = ?", (self.published_at = self.class.send(:current_time))]), ["#{self.class.primary_key} = ?", id]
          end
          freeze
        end

        def destroy_with_callbacks!
          return false if callback(:before_destroy) == false
          result = destroy_without_callbacks!
          callback(:after_destroy)
          result
        end

        def destroy!
          transaction { destroy_with_callbacks! }
        end

        def published?
          !!read_attribute(:published_at)
        end

        def recover!
          self.published_at = nil
          save!
        end
        
        def recover_with_associations!(*associations)
          self.recover!
          associations.to_a.each do |assoc|
            self.send(assoc).find_with_published(:all).each do |a|
              a.recover! if a.class.viewable?
            end
          end
        end
      end
    end
  end
end
