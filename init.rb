class << ActiveRecord::Base
  def belongs_to_with_published(association_id, options = {})
    with_published = options.delete :with_published
    returning belongs_to_without_published(association_id, options) do
      if with_published
        reflection = reflect_on_association(association_id)
        association_accessor_methods(reflection,            Caboose::Acts::BelongsToWithPublishedAssociation)
        association_constructor_method(:build,  reflection, Caboose::Acts::BelongsToWithPublishedAssociation)
        association_constructor_method(:create, reflection, Caboose::Acts::BelongsToWithPublishedAssociation)
      end
    end
  end
  
  def has_many_without_published(association_id, options = {}, &extension)
    with_published = options.delete :with_published
    returning has_many_with_published(association_id, options, &extension) do
      if options[:through] && !with_published
        reflection = reflect_on_association(association_id)
        collection_reader_method(reflection, Caboose::Acts::HasManyThroughWithoutPublishedAssociation)
        collection_accessor_methods(reflection, Caboose::Acts::HasManyThroughWithoutPublishedAssociation, false)
      end
    end
  end
  
  alias_method_chain :belongs_to, :published
  alias_method :has_many_with_published, :has_many
  alias_method :has_many, :has_many_without_published
  alias_method :exists_with_published?, :exists?
end
ActiveRecord::Base.send :include, Caboose::Acts::Viewable
ActiveRecord::Base.send :include, Caboose::Acts::ViewableFindWrapper
class << ActiveRecord::Base
  alias_method_chain :acts_as_viewable, :find_wrapper
end


