# ~*~ encoding: utf-8 ~*~
require File.expand_path(File.join(File.dirname(__FILE__), "helper"))
require 'pp'

context "Document with page_file_dir option" do
  setup do
    @wiki = Gollum::Wiki.new(testpath('examples/doc_subdir.git'), :page_file_dir => 'docs')
    @path = temp_path
    @doc = @wiki.document(:output_path => @path)
  end

  test "get valid" do
    assert @doc.valid?
    nondoc = Gollum::Wiki.new(testpath("examples/lotr.git"))
    assert !nondoc.document
  end

  test "get settings" do
    settings = @doc.settings
    assert_equal 'My Book', settings['title']
    assert_equal 'Scott Chacon', settings['authors'].first
  end

  test "get pages list" do
    pages = @doc.pages.map { |p| p.path }
    pages = pages.join(':')
    assert_equal 'docs/My-Precious.md:docs/Mordor/Eye-Of-Sauron.md:docs/Mordor/Gates-Of-Mordor.md:docs/Bilbo-Baggins.md:docs/Home.textile:docs/Precious.textile', pages
  end

  test "get output path" do
    assert_equal @path, @doc.output_path
  end

  test "generate base html document" do
    path = @doc.generate(:base)
    assert ::File.file? path
  end

  test "generates toc from base doc" do
    toc = @doc.toc
    assert_equal 6, toc.size
  end

  test "copies all needed images, files" do
    path = @doc.generate(:base)
    assert ::File.file?(::File.join(@path, 'docs', 'Mordor', 'eye.jpg'))
  end
end

