#  (c) Aaron Gustafson
#  https://github.com/aarongustafson/jekyll-webmention_io 
#  Licence : MIT
#  
#  this liquid plugin insert a webmentions into your Octopress or Jekill blog
#  using http://webmention.io/ and the following syntax:
#
#    {% webmentions URL %}
#    {% webmention_count URL %}
#   
require 'json'

WEBMENTION_CACHE_DIR = File.expand_path('../../.webmention-cache', __FILE__)
FileUtils.mkdir_p(WEBMENTION_CACHE_DIR)

module Jekyll
  
  class Webmentions < Liquid::Tag
    
    def initialize(tagName, text, tokens)
      super
      @text = text
      @api_endpoint = ""
    end
    
    def render(context)
      output = super
      if @text =~ /([\w]+(\.[\w]+)*)/i
          target = lookup(context, $1)
      end
      api_params = {'target' => target}
      response = get_response(api_params)

      site = context.registers[:site]
      @converter = site.getConverterImpl(::Jekyll::Converters::Markdown)

      html_output_for(response)
    end

    def html_output_for(response)
      ""
    end
    
    def url_params_for(api_params)
      api_params.keys.sort.map do |k|
        "#{CGI::escape(k)}=#{CGI::escape(api_params[k])}"
      end.join('&')
    end

    def get_response(api_params)
      api_params = url_params_for(api_params)
      api_uri = URI.parse(@api_endpoint + "?#{api_params}")
      response = Net::HTTP.get(api_uri.host, api_uri.request_uri)
      if response
        JSON.parse(response)
      else
        ""
      end
    end
    
    def lookup(context, name)
      lookup = context

      name.split(".").each do |value|
        lookup = lookup[value]
      end

      lookup
    end

  end
  
  class WebmentionsTag < Webmentions
  
    def initialize(tagName, text, tokens)
      super
      @api_endpoint = "http://webmention.io/api/mentions"
    end

    def html_output_for(response)
      body = "<p class=\"webmentions__not-found\">No webmentions were found</p>"
      
      if response and response['links']
        body = parse_links(response['links'])
      end
      
      "<div class=\"webmentions\">#{body}</div>"
    end
    
    def parse_links(links)
      lis = ""
      
      links.reverse_each { |link|
        
        title = link["data"]["name"]
        content = link["data"]["content"]
        url = link["data"]["url"]
        link_title = title || url
        id = link["id"]
        
        if title and content and title == content
          title = false
        end
        
        if ! id
          time = Time.now();
          id = time.strftime("%s")
        end
        
        author_block = ""
        if author = link["data"]["author"]
          
          #puts author
          a_name = author["name"]
          a_url = author["url"]
          a_photo = author["photo"]
        
          if a_photo
            author_block << "<img class=\"webmention__author__photo u-photo\" src=\"#{a_photo}\" alt=\"\" title=\"#{a_name}\">"
          end
        
          name_block = "<b class=\"p-name\">#{a_name}</b>"
          author_block << name_block
        
          if a_url
            author_block = "<a class=\"u-url\" href=\"#{a_url}\">#{author_block}</a>"
          end
        
          author_block = "<div class=\"webmention__author p-author h-card\">#{author_block}</div>"
        end
        
        published_block = ""
        pubdate = link["data"]["published_ts"]
        pubdate_formatted = link["data"]["published_ts"]
        if pubdate and pubdate_formatted and pubdate_formatted = Time.at(pubdate_formatted)
          pubdate_formatted = pubdate_formatted.strftime("%-d %B %Y")
          published_block = "<time class=\"webmention__pubdate dt-published\" datetime=\"#{pubdate}\">#{pubdate_formatted}</time>"
        end
        
        webmention_classes = "webmention"
        if a_name and ( title and title.start_with?(a_name) ) or ( content and content.start_with?(a_name) )
          webmention_classes << ' webmention--author-starts'
        end
        
        content_block = ""
        if link_title and url
          webmention_classes << " webmention--title-only"
          content_block << "<div class=\"webmention__title p-name\"><a href=\"#{url}\">#{link_title}</a></div>"
          if published_block
            content_block << "<div class=\"webmention__meta\">#{published_block}</div>"
          end
        elsif content and url
          content = @converter.convert("#{content}")
          webmention_classes << " webmention--content-only"
          content_block << "<div class=\"webmention__meta\">"
          if published_block
            content_block << "#{published_block} | "
          end
          content_block << "<a class=\"webmention__source u-url\" href=\"#{url}\">Permalink</a></div>"
          content_block << "<div class=\"webmention__content p-content\">#{content}</div>"
        end
        
        # put it together
        lis << "<li id=\"webmention-#{id}\" class=\"webmentions__item\">"
        lis << "<article class=\"h-cite #{webmention_classes}\">"
        lis << author_block
        lis << content_block
        lis << "</article></li>"
        
      }

      "<ol class=\"webmentions__list\">#{lis}</ol>"
    end

  end

  class WebmentionCountTag < Webmentions
    
    def initialize(tagName, text, tokens)
      super
      @api_endpoint = "http://webmention.io/api/count"
    end

    def html_output_for(response)
      count = response['count'] || "0"
      "<span class=\"webmention-count\">#{count}</span>"
    end
    
  end
  
  class WebmentionGenerator < Generator
    safe true
    priority :low
    
    def generate(site)
      webmentions = {}
      if defined?(WEBMENTION_CACHE_DIR)
        cache_file = File.join(WEBMENTION_CACHE_DIR, "webmentions.yml")
        site.posts.each do |post|
          source = "#{site.config['url']}#{post.url}"
          targets = []
          if post.data['in_reply_to']
            targets.push(post.data['in_reply_to'])
          end
          post.content.scan(/(?:https?:)?\/\/[^\s)#"]+/) do |match|
            if ! targets.find_index( match )
              targets.push(match)
            end
          end
          webmentions[source] = targets
        end
        File.open(cache_file, 'w') { |f| YAML.dump(webmentions, f) }
      end
    end
  end
  
end

Liquid::Template.register_tag('webmentions', Jekyll::WebmentionsTag)
Liquid::Template.register_tag('webmention_count', Jekyll::WebmentionCountTag)