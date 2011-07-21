# ~*~ encoding: utf-8 ~*~
require File.expand_path(File.join(File.dirname(__FILE__), "helper"))
require 'pp'

context "Document" do
  setup do
    @wiki = Gollum::Wiki.new(testpath("examples/doc.git"))
    @path = temp_path
    @doc = @wiki.document(:output_path => @path)
  end

  test "get settings" do
    settings = @doc.settings
    assert_equal 'Test Doc', settings['title']
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
    `open #{path}`
  end

  xtest "generate html site" do
  end

  xtest "generate pdf" do
  end

  xtest "generate mobi" do
  end

  xtest "generate epub" do
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
