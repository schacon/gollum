# ~*~ encoding: utf-8 ~*~
require File.expand_path(File.join(File.dirname(__FILE__), "helper"))
require 'pp'

context "Document" do
  setup do
    @wiki = Gollum::Wiki.new(testpath("examples/doc.git"))
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
    assert_equal 'My-Precious.md:Mordor/Eye-Of-Sauron.md:Mordor/Gates-Of-Mordor.md:Bilbo-Baggins.md:Home.textile:Precious.textile', pages
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
    assert ::File.file?(::File.join(@path, 'Mordor', 'eye.jpg'))
  end

  test "does not regen html for the same site" do
    path = @doc.generate(:base)
    size1 = File.size(path)

    wiki = Gollum::Wiki.new(testpath("examples/doc.git"))
    doc = wiki.document(:output_path => @path)
    path = doc.generate(:base)
    size2 = File.size(path)
    assert_equal size1, size2
  end

  test "regens base html if commit changes" do
    path = @doc.generate(:base)
    size1 = File.size(path)

    wiki = Gollum::Wiki.new(testpath("examples/doc.git"), :ref => 'old')
    doc = wiki.document(:output_path => @path)
    path = doc.generate(:base)
    size2 = File.size(path)

    assert size1 != size2
  end


  test "generate single html file" do
    path = @doc.generate(:html)
    source = File.read(path)
    assert_match '<h1 id="Title">', source
    assert_match '<h2 id="Subsection-One">', source
    assert_match '<h3 id="Sub-Subsection">', source
    assert_match '<img src="./Mordor/eye.jpg"', source
    assert_match 'href="#Hobbit">', source
  end

  test "can test for path" do
    path = @doc.path(:base)
    assert_equal false, path
    @doc.generate(:base)
    path = @doc.path(:base)
    assert_equal ::File.join(@path, 'base.html'), path
  end

  test "generate pdf" do
    path = @doc.generate(:pdf)
    assert ::File.file? path
    assert ::File.size(path) > 30000 # has images
  end

  test "generate mobi" do
    path = @doc.generate(:mobi)
    assert path
    assert ::File.file? path
    #`/Applications/Kindle\\ Previewer.app/Contents/MacOS/Kindle\\ Previewer #{path}`
  end

  test "generate epub" do
    path = @doc.generate(:epub)
    assert path
    assert ::File.file? path
  end

  # ---- #

  xtest "can load html in chunks" do
  end

  xtest "single file html maintains internal links" do
    # href="/Hobbit" => href="#Hobbit"
  end

  xtest "single file html uses template" do
  end

  xtest "alternate settings file" do
  end

  xtest "alternate output dir" do
  end

  xtest "alternate input dir" do
  end

  xtest "alternate input branch" do
  end

end
