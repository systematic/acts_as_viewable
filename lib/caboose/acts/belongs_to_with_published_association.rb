module Caboose # :nodoc:
  module Acts # :nodoc:
    class BelongsToWithPublishedAssociation < ActiveRecord::Associations::BelongsToAssociation
      private
        def find_target
          @reflection.klass.find_with_published(
            @owner[@reflection.primary_key_name], 
            :conditions => conditions,
            :include    => @reflection.options[:include]
          )
        end
    end
  end
end
