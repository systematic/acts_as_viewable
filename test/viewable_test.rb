require File.join(File.dirname(__FILE__), 'test_helper')

class Widget < ActiveRecord::Base
  acts_as_viewable
  has_many :categories, :dependent => :destroy
  has_and_belongs_to_many :habtm_categories, :class_name => 'Category'
  has_one :category
  belongs_to :parent_category, :class_name => 'Category'
  has_many :taggings
  has_many :tags, :through => :taggings
  has_many :any_tags, :through => :taggings, :class_name => 'Tag', :source => :tag, :with_published => true
end

class Category < ActiveRecord::Base
  belongs_to :widget
  belongs_to :any_widget, :class_name => 'Widget', :foreign_key => 'widget_id', :with_published => true
  acts_as_viewable

  def self.search(name, options = {})
    find :all, options.merge(:conditions => ['LOWER(title) LIKE ?', "%#{name.to_s.downcase}%"])
  end

  def self.search_with_published(name, options = {})
    find_with_published :all, options.merge(:conditions => ['LOWER(title) LIKE ?', "%#{name.to_s.downcase}%"])
  end
end

class Tag < ActiveRecord::Base
  has_many :taggings
  has_many :widgets, :through => :taggings
end

class Tagging < ActiveRecord::Base
  belongs_to :tag
  belongs_to :widget
  acts_as_viewable
end

class NonViewableAndroid < ActiveRecord::Base
end

class ViewableTest < Test::Unit::TestCase
  fixtures :widgets, :categories, :categories_widgets, :tags, :taggings
  
  def test_should_recognize_with_published_option
    assert_equal [1, 2], Widget.find(:all, :with_published => true).collect { |w| w.id }
    assert_equal [1], Widget.find(:all, :with_published => false).collect { |w| w.id }
  end
  
  def test_should_recognize_only_published_option
    assert_equal [2], Widget.find(:all, :only_published => true).collect { |w| w.id }
    assert_equal [1], Widget.find(:all, :only_published => false).collect { |w| w.id }
  end
  
  def test_should_exists_with_published
    assert Widget.exists_with_published?(2)
    assert !Widget.exists?(2)
  end

  def test_should_exists_only_published
    assert Widget.exists_only_published?(2)
    assert !Widget.exists_only_published?(1)
  end

  def test_should_count_with_published
    assert_equal 1, Widget.count
    assert_equal 2, Widget.count_with_published
    assert_equal 1, Widget.count_only_published
    assert_equal 2, Widget.calculate_with_published(:count, :all)
  end

  def test_should_set_published_at
    assert_equal 1, Widget.count
    assert_equal 1, Category.count
    widgets(:widget_1).destroy
    assert_equal 0, Widget.count
    assert_equal 0, Category.count
    assert_equal 2, Widget.calculate_with_published(:count, :all)
    assert_equal 4, Category.calculate_with_published(:count, :all)
  end
  
  def test_should_destroy
    assert_equal 1, Widget.count
    assert_equal 1, Category.count
    widgets(:widget_1).destroy!
    assert_equal 0, Widget.count
    assert_equal 0, Category.count
    assert_equal 1, Widget.count_only_published
    assert_equal 1, Widget.calculate_with_published(:count, :all)
    # Category doesn't get destroyed because the dependent before_destroy callback uses #destroy
    assert_equal 4, Category.calculate_with_published(:count, :all)
  end
  
  def test_should_delete_all
    assert_equal 1, Widget.count
    assert_equal 2, Widget.calculate_with_published(:count, :all)
    assert_equal 1, Category.count
    Widget.delete_all
    assert_equal 0, Widget.count
    # delete_all doesn't call #destroy, so the dependent callback never fires
    assert_equal 1, Category.count
    assert_equal 2, Widget.calculate_with_published(:count, :all)
  end
  
  def test_should_delete_all_with_conditions
    assert_equal 1, Widget.count
    assert_equal 2, Widget.calculate_with_published(:count, :all)
    Widget.delete_all("id < 3")
    assert_equal 0, Widget.count
    assert_equal 2, Widget.calculate_with_published(:count, :all)
  end
  
  def test_should_delete_all2
    assert_equal 1, Category.count
    assert_equal 4, Category.calculate_with_published(:count, :all)
    Category.delete_all!
    assert_equal 0, Category.count
    assert_equal 0, Category.calculate_with_published(:count, :all)
  end
  
  def test_should_delete_all_with_conditions2
    assert_equal 1, Category.count
    assert_equal 4, Category.calculate_with_published(:count, :all)
    Category.delete_all!("id < 3")
    assert_equal 0, Category.count
    assert_equal 2, Category.calculate_with_published(:count, :all)    
  end
  
  def test_should_not_count_published
    assert_equal 1, Widget.count
    assert_equal 1, Widget.count(:all, :conditions => ['title=?', 'widget 1'])
    assert_equal 2, Widget.calculate_with_published(:count, :all)
    assert_equal 1, Widget.count_only_published
  end
  
  def test_should_find_only_published
    assert_equal [2], Widget.find_only_published(:all).collect { |w| w.id }
    assert_equal [1, 2], Widget.find_with_published(:all, :order => 'id').collect { |w| w.id }
  end
  
  def test_should_not_find_published
    assert_equal [widgets(:widget_1)], Widget.find(:all)
    assert_equal [1, 2], Widget.find_with_published(:all, :order => 'id').collect { |w| w.id }
  end
  
  def test_should_not_find_published_has_many_associations
    assert_equal 1, widgets(:widget_1).categories.size
    assert_equal [categories(:category_1)], widgets(:widget_1).categories
  end
  
  def test_should_not_find_published_habtm_associations
    assert_equal 1, widgets(:widget_1).habtm_categories.size
    assert_equal [categories(:category_1)], widgets(:widget_1).habtm_categories
  end
  
  def test_should_not_find_published_has_many_through_associations
    assert_equal 1, widgets(:widget_1).tags.size
    assert_equal [tags(:tag_2)], widgets(:widget_1).tags
  end
  
  def test_should_find_has_many_through_associations_with_published
    assert_equal 2, widgets(:widget_1).any_tags.size
    assert_equal Tag.find(:all), widgets(:widget_1).any_tags
  end

  def test_should_not_find_published_belongs_to_associations
    assert_nil Category.find_with_published(3).widget
  end

  def test_should_find_belongs_to_assocation_with_published
    assert_equal Widget.find_with_published(2), Category.find_with_published(3).any_widget
  end

  def test_should_find_first_with_published
    assert_equal widgets(:widget_1), Widget.find(:first)
    assert_equal 2, Widget.find_with_published(:first, :order => 'id desc').id
  end
  
  def test_should_find_single_id
    assert Widget.find(1)
    assert Widget.find_with_published(2)
    assert_raises(ActiveRecord::RecordNotFound) { Widget.find(2) }
  end
  
  def test_should_find_multiple_ids
    assert_equal [1,2], Widget.find_with_published(1,2).sort_by { |w| w.id }.collect { |w| w.id }
    assert_equal [1,2], Widget.find_with_published([1,2]).sort_by { |w| w.id }.collect { |w| w.id }
    assert_raises(ActiveRecord::RecordNotFound) { Widget.find(1,2) }
  end
  
  def test_should_ignore_multiple_includes
    Widget.class_eval { acts_as_viewable }
    assert Widget.find(1)
  end

  def test_should_not_override_scopes_when_counting
    assert_equal 1, Widget.send(:with_scope, :find => { :conditions => "title = 'widget 1'" }) { Widget.count }
    assert_equal 0, Widget.send(:with_scope, :find => { :conditions => "title = 'published widget 2'" }) { Widget.count }
    assert_equal 1, Widget.send(:with_scope, :find => { :conditions => "title = 'published widget 2'" }) { Widget.calculate_with_published(:count, :all) }
  end

  def test_should_not_override_scopes_when_finding
    assert_equal [1], Widget.send(:with_scope, :find => { :conditions => "title = 'widget 1'" }) { Widget.find(:all) }.ids
    assert_equal [],  Widget.send(:with_scope, :find => { :conditions => "title = 'published widget 2'" }) { Widget.find(:all) }.ids
    assert_equal [2], Widget.send(:with_scope, :find => { :conditions => "title = 'published widget 2'" }) { Widget.find_with_published(:all) }.ids
  end

  def test_should_allow_multiple_scoped_calls_when_finding
    Widget.send(:with_scope, :find => { :conditions => "title = 'published widget 2'" }) do
      assert_equal [2], Widget.find_with_published(:all).ids
      assert_equal [2], Widget.find_with_published(:all).ids, "clobbers the constrain on the unmodified find"
      assert_equal [], Widget.find(:all).ids
      assert_equal [], Widget.find(:all).ids, 'clobbers the constrain on a viewable find'
    end
  end

  def test_should_allow_multiple_scoped_calls_when_counting
    Widget.send(:with_scope, :find => { :conditions => "title = 'published widget 2'" }) do
      assert_equal 1, Widget.calculate_with_published(:count, :all)
      assert_equal 1, Widget.calculate_with_published(:count, :all), "clobbers the constrain on the unmodified find"
      assert_equal 0, Widget.count
      assert_equal 0, Widget.count, 'clobbers the constrain on a viewable find'
    end
  end

  def test_should_give_viewable_status
    assert Widget.viewable?
    assert !NonViewableAndroid.viewable?
  end

  def test_should_give_record_status
    assert_equal false, Widget.find(1).published? 
    Widget.find(1).destroy
    assert Widget.find_with_published(1).published?
  end

  def test_should_find_published_has_many_assocations_on_published_records_by_default
    w = Widget.find_with_published 2
    assert_equal 2, w.categories.find_with_published(:all).length
    assert_equal 2, w.categories.find_with_published(:all).size
  end
  
  def test_should_find_published_habtm_assocations_on_published_records_by_default
    w = Widget.find_with_published 2
    assert_equal 2, w.habtm_categories.find_with_published(:all).length
    assert_equal 2, w.habtm_categories.find_with_published(:all).size
  end

  def test_dynamic_finders
    assert     Widget.find_by_id(1)
    assert_nil Widget.find_by_id(2)
  end

  def test_custom_finder_methods
    w = Widget.find_with_published(:all).inject({}) { |all, w| all.merge(w.id => w) }
    assert_equal [1],       Category.search('c').ids
    assert_equal [1,2,3,4], Category.search_with_published('c', :order => 'id').ids
    assert_equal [1],       widgets(:widget_1).categories.search('c').collect(&:id)
    assert_equal [1,2],     widgets(:widget_1).categories.search_with_published('c').ids
    assert_equal [],        w[2].categories.search('c').ids
    assert_equal [3,4],     w[2].categories.search_with_published('c').ids
  end
  
  def test_should_recover_record
    Widget.find(1).destroy
    assert_equal true, Widget.find_with_published(1).published? 
    
    Widget.find_with_published(1).recover!
    assert_equal false, Widget.find(1).published?
  end
  
  def test_should_recover_record_and_has_many_associations
    Widget.find(1).destroy
    assert_equal true, Widget.find_with_published(1).published?
    assert_equal true, Category.find_with_published(1).published?
    
    Widget.find_with_published(1).recover_with_associations!(:categories)
    assert_equal false, Widget.find(1).published?
    assert_equal false, Category.find(1).published?
  end
end

class Array
  def ids
    collect &:id
  end
end
