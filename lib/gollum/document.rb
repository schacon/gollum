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
      @toc_file = 'toc.yml'

      @single_html_file = 'single.html'

      parse_settings
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

    def generate(type = :html)
      path = generate_base
      case type
      when :base
        return path
      when :html
        return generate_html
      #when :mobi
      #  return generate_mobi
      end
    end

    def toc
      generate_base
      toc = parse_yml_file(outpath(@toc_file))
    end

    private

    # - write the base consolidated html content file
    # - write table of contents file generated from the content (h1, h2, h3)
    # - copy referenced images and files into assets directories
    # - write checksum of when these were generated
    def generate_base
      version = @wiki.version_sha

      checksums_path = outpath(@checksums_file)
      checksums = parse_yml_file(checksums_path)

      outfile_path = outpath(@base_html_file)

      return outfile_path if ::File.file?(outfile_path) && (checksums[:base] == version)

      of = ::File.open(outfile_path, 'w+')
      pages.each do |page|
        content = page.formatted_data
        content = insert_section_ids(content)
        content = rewrite_asset_links(content)
        of.write "<!-- " + page.path + " -->\n"
        of.write "<a target=\"" + strip_html(page.title.gsub(' ', '-')) + "\"/>\n"
        of.write content
        of.write "\n\n"
      end
      of.close

      generate_toc

      # check out all non-page files into the output directory (images and whatnot)
      @wiki.non_pages.each do |path|
        write_to = outpath(path)
        FileUtils.mkdir_p(::File.dirname(write_to))
        wt = ::File.open(write_to, 'w+')
        wt.write @wiki.file(path).raw_data
        wt.close
      end

      checksums[:base] = version
      save_yml_file(checksums_path, checksums)

      outfile_path
    end

    # read the base html file and generate a table of contents
    # based on the header tags
    def generate_toc
      toc = []
      source = ::File.read(outpath(@base_html_file))
      source.scan(/\<h([1|2|3]) id=\"(.*?)\"\>(.*?)\<\/h[1|2|3]\>/).each do |header|
        sec = {'id' => header[1], 'name' => strip_html(header[2]), 'subsections' => []}
        if header[0] == '1' 
          toc << sec
        elsif header[0] == '2'
          toc.last['subsections'] << sec
        else
          subtoc = toc.last['subsections'].last['subsections'] << sec
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

    def generate_html
      generate_base
      source = ::File.read(outpath(@base_html_file))
      outfile_path = outpath(@single_html_file)

      asset_dir = ::File.join(GOLLUM_ROOT, 'site', 'default', 'assets')
      FileUtils.cp_r(asset_dir, outpath('.'))

      index_template = liquid_template('index.html')

      data = { 
        'book_title' => @settings['title'],
        'content' => source
      }

      of = ::File.open(outfile_path, 'w+')
      of.write( index_template.render(data) )
      of.close

      outfile_path
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

