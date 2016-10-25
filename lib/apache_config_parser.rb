require 'ox'
require '../lib/apache_config_parser/apache_config_entry'
require '../lib/apache_config_parser/apache_config_section'
require '../lib/apache_config_parser/apache_config_tree'

module ApacheConfigParser

  def ApacheConfigParser.parse(config)

    tokens = "<Token type='configuration'>\n"

    line_enumerator = config.lines.each

    begin

      while true do

        line = line_enumerator.next

        # Split Indentation from Statement

        captured = line.match(/(?<indent>\s*)(?<statement>.*)/)

        size = captured[:indent].to_s.length

        # Comments and Blank Lines

        if captured[:statement].start_with?('#') || captured[:statement].length ==0

          tokens <<-"<Token type='comment' indent='#{size}'><![CDATA[#{captured[:statement]}]]></Token>\n"

          next

        end

        # Start Tag

        if start_tag = captured[:statement].match(/\<(?<name>\w*[^>])(\>|\s(?<parameters>.*)\>)/)

          tokens <<-"<Token type='section' name='#{start_tag[:name]}' indent='#{size}' parameters='#{start_tag[:parameters].encode(:xml => :attr)[1..-2]}'>\n"

          next

        end

        # End Tag (As they match xml they are only identified by the regex)

        if end_tag = captured[:statement].match(/\<\/(?<name>\w*[^>])\>/)

          tokens <<-"</Token>\n"

          next

        end

        # Key Value Pairs

        if key_pair = captured[:statement].match(/^(?<name>\w*)\s?(?<value>.*)/)

          if key_pair[:value].end_with?('\\')

            tokens << "<Token type='entry' indent='#{size}' name='#{key_pair[:name]}'><Token type='value'><![CDATA[#{key_pair[:value].to_s[0..-1]}></Token>"

            line_enumerator.peek_values.each do |peeked_line|

              if peeked_line.end_with?('\\')

                tokens << "<Token type='value'>#{line_enumerator.next}[0..-1]</Token>"

              else

                tokens << "<Token type='value'>#{line_enumerator.next}]]></Token></Token>\n"

                break

              end

            end

          else

            tokens << "<Token type='entry' indent='#{size}' name='#{key_pair[:name]}'><Token type='value'><![CDATA[#{key_pair[:value].to_s}]]></Token></Token>\n"

          end

        end

      end

    rescue StopIteration

      tokens << '</Token>'

      tree = ApacheConfigTree.new

      root = Ox.parse(tokens)

      root.nodes.each do |token|

        process(tree, token)

      end

      tree

    end

  end

  def self.process(parent, token)

    type = token.attributes[:type]

    case type

      when 'comment'

        parent.entries.push(ApacheConfigEntry.new(token.attributes[:indent], type, '', token.nodes[0].value))

      when 'entry'

        entry = parent.entries.push(ApacheConfigEntry.new(token.attributes[:indent], type, token.attributes[:name], token.nodes[0].value))

        parent.entries.push(entry)

        token.nodes.each do |line_token|

          process(entry, line_token)

        end


      when 'value'




      when 'section'

        section = parent.entries.push(ApacheConfigSection.new(token.attributes[:parameters]))

        token.nodes.each do |child_token|

          process(section, child_token)

        end

    end

  end

end