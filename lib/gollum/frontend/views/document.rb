module Precious
  module Views
    class Document < Layout
      attr_reader :content, :page, :footer

      def title
        @doc.settings['title']
      end

    end
  end
end

