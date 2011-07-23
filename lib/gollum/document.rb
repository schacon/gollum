module Gollum
  class Document

    # wiki object used as a base for the document
    attr_reader :wiki

    # document settings
    attr_reader :settings

    # document settings file path
    attr_reader :settings_file

    # document generation output path
    attr_reader :output_path

    def initialize(wiki, options = {})
      @wiki = wiki
      @settings_file = options[:settings_file] || '_Document.yml'
      @output_path = options[:output_path] || ::File.join(@wiki.git_path, 'gollum', @wiki.version_sha)
      FileUtils.mkdir_p(@output_path) if !::File.exists?(@output_path)

      @base_html_file = 'base.html'
      @checksums_file = 'checksums.yml'
      @toc_file       = 'toc.yml'

      @html_file = 'doc.html'
      @pdf_file  = 'doc.pdf'
      @mobi_file = 'doc.mobi'
      @epub_file = 'doc.epub'

      @ncx_file  = 'doc.ncx'
      @opf_file  = 'doc.opf'

      parse_settings
    end

    def valid?
      @settings['toc']
    end

    # filter and order the wiki pages according to the document settings file
    def pages
      toc = []
      p = @wiki.pages
      @settings['toc'].each do |entry|
        toc << p.select { |page| wc_match(page.path, entry + '*') }
      end
      toc.flatten.uniq.compact
    end

    # check for the generated document artifact, either return false if it hasn't
    # been generated yet, or return the path to the artifact
    def path(type = :base)
      version = @wiki.version_sha
      checksums_path = outpath(@checksums_file)
      checksums = parse_yml_file(checksums_path)

      path = false
      case type
      when :base
        path = outpath(@base_html_file)
      when :html
        path = outpath(@html_file)
      when :pdf
        path = outpath(@pdf_file)
      when :mobi
        path = outpath(@mobi_file)
      when :epub
        path = outpath(@epub_file)
      when :opf
        path = outpath(@opf_file)
      end
      return path if path && ::File.file?(path) && (checksums[type] == version)
      false
    end

    def generate(type = :base)
      path = generate_base
      case type
      when :base
        return path
      when :html
        return generate_html
      when :pdf
        return generate_pdf
      when :mobi
        return generate_mobi
      when :epub
        return generate_epub
      end
    end

    def toc
      generate_base
      toc = parse_yml_file(outpath(@toc_file))
    end

    def book_title
      @settings['title'] || 'Title'
    end

    private

    # - write the base consolidated html content file
    # - write table of contents file generated from the content (h1, h2, h3)
    # - copy referenced images and files into assets directories
    # - write checksum of when these were generated
    def generate_base
      prereq :base do
        outfile_path = outpath(@base_html_file)

        pagecount = 0
        of = ::File.open(outfile_path, 'w+')
        pages.each do |page|
          content = page.formatted_data
          content = insert_section_ids(content)
          content = rewrite_asset_links(content)
          pagecount += 1
          of.write "<!-- " + page.path + " -->\n"
          of.write "<div id=\"page-#{pagecount}\" class=\"page\">"
          of.write "<a target=\"" + strip_html(page.title.gsub(' ', '-')) + "\"/>\n"
          of.write content
          of.write "\n</div>\n\n"
        end
        of.close

        generate_toc

        # check out all non-page files into the output directory (images and whatnot)
        copy_non_pages
        outfile_path
      end
    end

    def copy_non_pages(dir = nil)
      @wiki.non_pages.each do |opath|
        path = opath
        path = ::File.join(dir, opath) if dir
        write_to = outpath(path)
        FileUtils.mkdir_p(::File.dirname(write_to))
        wt = ::File.open(write_to, 'w+')
        wt.write @wiki.file(opath).raw_data
        wt.close
      end
    end

    def generate_html
      prereq :html, generate_base do |base_path|
        source = ::File.read(base_path)
        outfile_path = outpath(@html_file)

        asset_dir = ::File.join(GOLLUM_ROOT, 'site', 'default', 'assets')
        FileUtils.cp_r(asset_dir, outpath('.'))

        index_template = liquid_template('index.html')

        data = { 
          'book_title' => book_title,
          'content' => source
        }

        of = ::File.open(outfile_path, 'w+')
        of.write( index_template.render(data) )
        of.close

        outfile_path
      end
    end

    def generate_pdf
      prereq :pdf, generate_base do |base_path|
        outfile_path = outpath(@pdf_file)
        cmd = "wkhtmltopdf #{base_path} #{outfile_path}"
        if ex(cmd) 
          save_checksum(:pdf)
          outfile_path
        end
      end
    end

    def get_nav
      nav = []
      toc.each_with_index do |section, i|
        nav << {:label => "#{i + 1}. " + section['name'], :content => "#{@html_file}##{section['id']}"}
        section['subsections'].each_with_index do |sub, j|
          nav << {:label => "#{i + 1}.#{j + 1} " + sub['name'], :content => "#{@html_file}##{sub['id']}"}
        end
      end
      nav
    end

    def book_identifier
      @wiki.version_sha
    end

    def book_identifier_scheme
      "GITHUB-SHA"
    end

    def generate_opf
      prereq :opf, generate_html do |base_path|
        Dir.chdir(@output_path) do
          cover_image = @settings['cover'] || 'assets/cover.jpg'

          nav = get_nav

          # CREATE NCX FILE
          EeePub::NCX.new(
            :title => book_title,
            :nav => nav
          ).save(@ncx_file)

          # CREATE HTML TOC FILE
          html_toc_file = 'toc.html'
          html = ::File.open(html_toc_file, 'w+')
          html.puts('<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
          <html xmlns="http://www.w3.org/1999/xhtml">
          <head><title>Table of Contents</title></head><body>
          <div><h1><b>TABLE OF CONTENTS</b></h1><br/>')

          chapters = 0
          toc.each do |section|
            chapters += 1

            html.puts('<h3><b>Chapter ' + chapters.to_s + '<br/>')
            html.puts("<a href=\"#{@html_file}#" + section['id'] + '">' + section['name'] + '</a></b></h3><br/>')

            section['subsections'].each do |sub|
              html.puts("<a href=\"#{@html_file}#" + sub['id'] + '"><b>' + sub['name'] + '</b></a><br/>')
            end
          end
          html.puts('<h1 class="centered">* * *</h1></div></body></html>')
          html.close

          # CREATE OPF FILE
          EeePub::OPF.new(
            :title => book_title,
            :identifier => {:value => book_identifier, :scheme => book_identifier_scheme},
            :manifest => [
              @html_file,
              html_toc_file,
              {:id => 'cover', :href => cover_image}
            ],
            :guide => [
              {:type => 'toc',  :title => 'Table of Contents', :href => html_toc_file},
              {:type => 'text', :title => 'Contents', :href => @html_file}
            ],
            :ncx => @ncx_file
          ).save(@opf_file)

          # stupid cover hack for kindle
          opf_content = ::File.read(@opf_file)
          opf_content.gsub!('</metadata>', '<meta name="cover" content="cover"></metadata>')
          ::File.open(@opf_file, 'w+') { |f| f.write opf_content }
          # end stupid hack
        end
        outfile_path = outpath(@opf_file)
        if ::File.file?(outfile_path)
          outfile_path
        end
      end
    end

    def generate_mobi
      prereq :mobi, generate_opf do |opf_path|
        Dir.chdir(@output_path) do
          cmd = "kindlegen -verbose #{opf_path} -o #{@mobi_file}"
          ex(cmd)
        end
        outfile_path = outpath(@mobi_file)
        ::File.file?(outfile_path) ?  outfile_path : false
      end
    end

    def generate_epub
      prereq :epub, generate_opf do |opf_path|
        outfile_path = outpath(@epub_file)

        flist = @wiki.non_pages.map do |path|
          {outpath(path) => ::File.dirname(path)}
        end
        flist << {outpath(@html_file) => ::File.dirname(@html_file)}

        nlist = get_nav

        # TODO: fix this metadata
        title = book_title
        cr  = @settings['authors'].first rescue 'Anon'
        pub = @settings['publisher'] || 'GitHub Press'
        dt  = Time.now.strftime("%Y-%m-%d")
        bid = book_identifier
        bids = book_identifier_scheme
        epub = EeePub.make do
          title       title
          creator     cr
          publisher   pub
          date        dt
          identifier  bid, :scheme => bids
          files flist
          nav   nlist
        end
        epub.save(outfile_path)

        outfile_path
      end
    end


    def ex(command)
      @last_out = `#{command} 2>&1`
      $?.exitstatus == 0
    end

    def prereq(type, pre = true)
      if p = path(type)
        return p 
      end
      if !pre
        return false
      end
      path = yield pre
      if path
        save_checksum(:base)
      end
      path
    end

    # read the base html file and generate a table of contents
    # based on the header tags
    # TODO: clean this the fuck up - handle properly if a previous h1 or h2 doesn't exist
    def generate_toc
      toc = []
      source = ::File.read(outpath(@base_html_file))
      source.scan(/\<h([1|2|3]) id=\"(.*?)\"\>(.*?)\<\/h[1|2|3]\>/).each do |header|
        sec = {'id' => header[1], 'name' => strip_html(header[2]), 'subsections' => []}
        if header[0] == '1' 
          toc << sec
        elsif header[0] == '2'
          begin
            toc.last['subsections'] << sec
          rescue
            nil
          end
        else
          begin
            subtoc = toc.last['subsections'].last['subsections'] << sec
          rescue
            nil
          end
        end
      end
      save_yml_file(outpath(@toc_file), toc)
      toc
    end

    # take the generated base html document and insert ids into the 
    # headers that do not have them
    def insert_section_ids(data)
      @section_ids ||= {}
      data.gsub(/\<h([1|2|3])>(.*?)\<\/h[1|2|3]\>/).each do |header|
        level = $1
        title = $2
        base_id = id = strip_html(title.gsub(' ', '-'))
        counter = 1
        while @section_ids[id]
          counter += 1
          id = base_id + '-' + counter.to_s
        end
        @section_ids[id] = true
        "<h#{level} id=\"#{id}\">#{title}</h#{level}>"
      end
    end

    def rewrite_asset_links(data)
      data.gsub!(/src="(\/.*?)"/).each do |link|
        url = $1
        "src=\".#{url}\""
      end
      data.gsub(/href="\/(.*?)"/).each do |link|
        url = $1
        "href=\"##{url}\""
      end
    end

    def strip_html(str)
      str.gsub(/<\/?[^>]*>/, "")
    end

    def outpath(file)
      ::File.join(@output_path, file)
    end

    def parse_yml_file(file)
      return {} if !::File.file? file
      yml = ::File.read(file)
      YAML::parse(yml).transform
    end

    def save_yml_file(file, data)
      ::File.open(file, 'w+') do |f|
        f.write YAML::dump(data)
      end
    end

    def save_checksum(type)
      version = @wiki.version_sha
      checksums_path = outpath(@checksums_file)
      checksums = parse_yml_file(checksums_path)
      checksums[type] = version
      save_yml_file(checksums_path, checksums)
    end

    def parse_settings
      yml = @wiki.file(@settings_file)
      if yml
        data = yml.raw_data
        @settings = YAML::parse(data).transform
      else
        @settings = {}
      end
    end

    def liquid_template(file)
      template_dir = ::File.join(GOLLUM_ROOT, 'site', 'default')
      Liquid::Template.parse(::File.read(::File.join(template_dir, file)))
    end

    # do wildcard matching on string from pattern
    # escape everything but *, ^ and $
    # return true if it matches, 
    def wc_match(string, pattern)
      pattern = Regexp.escape(pattern).gsub('\*','.*?').gsub('\^', '^').gsub('\$', '$')
      matcher = Regexp.new pattern, Regexp::IGNORECASE
      !!(matcher =~ string)
    end
    

  end
end

