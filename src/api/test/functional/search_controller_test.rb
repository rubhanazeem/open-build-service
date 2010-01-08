require File.dirname(__FILE__) + '/../test_helper'
require 'search_controller'

# Re-raise errors caught by the controller.
class SearchController; def rescue_action(e) raise e end; end

class SearchControllerTest < ActionController::IntegrationTest 
  
  fixtures :db_projects, :db_packages, :users, :project_user_role_relationships, :roles, :static_permissions, :roles_static_permissions, :attrib_types, :attrib_namespaces, :attribs

  def setup
    @controller = SearchController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
 
    @tom = User.find_by_login("tom")
    @tscholz = User.find_by_login("tscholz")
  end

  def test_search_unknown
    ActionController::IntegrationTest::reset_auth
    get "/search/attribute?namespace=OBS&name=FailedCommend"
    assert_response 401

    prepare_request_with_user @request, "tscholz", "asdfasdf" 
    get "/search/attribute?namespace=OBS&name=FailedCommend"
    assert_response 404
    assert_select "status[code] > summary", /no such attribute/
  end

  def test_search_one_maintained_package
    ActionController::IntegrationTest::reset_auth
    get "/search/attribute?namespace=OBS&name=Maintained"
    assert_response 401

    prepare_request_with_user @request, "tscholz", "asdfasdf"
    get "/search/attribute?namespace=OBS&name=Maintained"
    assert_response :success
    assert_tag :tag => 'attribute', :attributes => { :name => "Maintained", :namespace => "OBS" }, :children => { :count => 1 }
    assert_tag :child => { :tag => 'project', :attributes => { :name => "Apache"}, :children => { :count => 1 } }
    assert_tag :child => { :child => { :tag => 'package', :attributes => { :name => "apache2" }, :children => { :count => 0 } } }
  end

  def test_xpath_1
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    get "/search/package", :match => '[@name="apache2"]'
    assert_response :success
    assert_tag :tag => 'collection', :children => { :count => 1 }
    assert_tag :child => { :tag => 'package', :attributes => { :name => 'apache2', :project => "Apache"} }
  end

  def test_xpath_2
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    get "/search/package", :match => '[attribute/@name="OBS:Maintained"]'
    assert_response :success
    assert_tag :tag => 'collection', :children => { :count => 1 }
    assert_tag :child => { :tag => 'package', :attributes => { :name => 'apache2', :project => "Apache"} }
  end

  def test_xpath_3
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    get "/search/package", :match => '[attribute/@name="OBS:Maintained" and @name="apache2"]'
    assert_response :success
    assert_tag :tag => 'collection', :children => { :count => 1 }
    assert_tag :child => { :tag => 'package', :attributes => { :name => 'apache2', :project => "Apache"} }
  end

  def test_xpath_4
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    get "/search/package", :match => '[attribute/@name="OBS:Maintained" and @name="Testpack"]'
    assert_response :success
    assert_tag :tag => 'collection', :children => { :count => 0 }
  end
  
end

