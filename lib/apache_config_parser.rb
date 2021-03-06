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

            tokens << "<Token type='entry' indent='#{size}' name='#{key_pair[:name]}'><Token type='value'><![CDATA[#{key_pair[:value].to_s[0..-2]}]]></Token>"

            line_enumerator.peek_values.each do |peeked_line|

              if peeked_line.end_with?('\\')

                tokens << "<Token type='value'><![CDATA[#{line_enumerator.next[0..-2]}]]></Token>"

              else

                tokens << "<Token type='value'><![CDATA[#{line_enumerator.next[0..-2]}]]></Token></Token>"

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

        entry  = ApacheConfigEntry.new(token.attributes[:indent], type, '')

        parent.entries.push(entry)

        entry.values.push(token.nodes[0].value)

      when 'entry'

        entry = ApacheConfigEntry.new(token.attributes[:indent], type, token.attributes[:name])

        parent.entries.push(entry)

        #entry.values.push(token.nodes[0].value)

        token.nodes.each do |child_token|

          process(entry, child_token)

        end

      when 'value'

        parent.values.push(token.nodes[0].value)

      when 'section'

        section = ApacheConfigSection.new(token.attributes[:name], token.attributes[:parameters])

        parent.entries.push(section)

        token.nodes.each do |child_token|

          process(section, child_token)

        end

    end

  end

end