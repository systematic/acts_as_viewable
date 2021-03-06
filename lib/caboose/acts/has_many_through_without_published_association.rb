module Caboose # :nodoc:
  module Acts # :nodoc:
    class HasManyThroughWithoutPublishedAssociation < ActiveRecord::Associations::HasManyThroughAssociation
      protected
        def old_current_time
          ActiveRecord::Base.default_timezone == :utc ? Time.now.utc : Time.now
        end
#superfluous
        def current_time
           $CURRENT_PUBLISHING_TIME || old_current_time
        end
        
        def construct_conditions
          return super unless @reflection.through_reflection.klass.viewable?
          table_name = @reflection.through_reflection.table_name
          conditions = construct_quoted_owner_attributes(@reflection.through_reflection).map do |attr, value|
            "#{table_name}.#{attr} = #{value}"
          end

          published_attribute = @reflection.through_reflection.klass.published_attribute
          quoted_current_time = @reflection.through_reflection.klass.quote_value(
            current_time,
            @reflection.through_reflection.klass.columns_hash[published_attribute.to_s])
          conditions << "#{table_name}.#{published_attribute} IS NULL OR #{table_name}.#{published_attribute} < #{quoted_current_time}"

          conditions << sql_conditions if sql_conditions
          "(" + conditions.join(') AND (') + ")"
        end
    end
  end
end
