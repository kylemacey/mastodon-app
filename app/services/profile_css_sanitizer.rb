# frozen_string_literal: true

require 'crass'

class ProfileCssSanitizer
  SCOPED_AT_RULES = %w(media supports container layer).freeze
  PASSTHROUGH_AT_RULES = %w(keyframes -webkit-keyframes font-face).freeze
  DANGEROUS_CSS_PARTS = %r{expression\s*\(|javascript:|data:|-moz-binding|</?style}i

  def self.call(css, scope_selector)
    new(css, scope_selector).call
  end

  def initialize(css, scope_selector)
    @css = css.to_s
    @scope_selector = scope_selector
  end

  def call
    return '' if @css.blank? || @scope_selector.blank?
    return '' if @css.match?(DANGEROUS_CSS_PARTS)

    sanitize_nodes(Crass.parse(@css)).join("\n")
  end

  private

  def sanitize_nodes(nodes)
    nodes.filter_map do |node|
      case node[:node]
      when :style_rule
        sanitize_style_rule(node)
      when :at_rule
        sanitize_at_rule(node)
      end
    end
  end

  def sanitize_at_rule(node)
    name = node[:name].to_s.downcase

    prelude = serialize_tokens(node[:prelude])
    return if prelude.match?(DANGEROUS_CSS_PARTS) || prelude.include?(';')

    return sanitize_scoped_at_rule(name, prelude, node) if SCOPED_AT_RULES.include?(name)

    return unless PASSTHROUGH_AT_RULES.include?(name)

    block = serialize_tokens(node[:block])
    return if block.blank? || block.match?(DANGEROUS_CSS_PARTS)

    "@#{name} #{prelude.strip} {\n#{block.strip}\n}"
  end

  def sanitize_scoped_at_rule(name, prelude, node)
    block = serialize_tokens(node[:block])
    inner_css = sanitize_nodes(Crass.parse(block)).join("\n")
    return if inner_css.blank?

    "@#{name} #{prelude.strip} {\n#{inner_css}\n}"
  end

  def sanitize_style_rule(node)
    selectors = scoped_selectors(node[:selector])
    properties = safe_properties(node[:children])

    return if selectors.empty? || properties.empty?

    "#{selectors.join(', ')} { #{properties.join('; ')}; }"
  end

  def scoped_selectors(selector_node)
    split_selector_list(selector_node&.dig(:value).to_s).filter_map do |selector|
      selector = selector.strip
      next if selector.blank?
      next if selector.match?(/[{};]/)

      scope_selector(selector)
    end
  end

  def scope_selector(selector)
    return selector.sub(/\A&/, @scope_selector) if selector.start_with?('&')

    scoped_root_selector = selector.sub(/\A(?:html|body|:root)(?=[\s.#:>+~\[]|$)/i, @scope_selector)
    return scoped_root_selector if scoped_root_selector.start_with?(@scope_selector)

    "#{@scope_selector} #{selector}"
  end

  def safe_properties(children)
    Array(children).filter_map do |child|
      next unless child[:node] == :property

      property = child[:name].to_s.downcase
      value = child[:value].to_s.strip
      next unless property.match?(/\A-{0,2}[a-z][a-z0-9-]*\z/)
      next if value.blank? || value.match?(DANGEROUS_CSS_PARTS)

      "#{property}: #{value}#{' !important' if child[:important]}"
    end
  end

  def split_selector_list(value)
    value.each_char.with_object([+'']) do |char, selectors|
      selectors.last << char
      next unless char == ','

      selectors.last.chop!
      selectors << +''
    end
  end

  def serialize_tokens(tokens)
    Array(tokens).map do |token|
      token[:raw] || serialize_tokens(token[:tokens]) || serialize_tokens(token[:value])
    end.join
  end
end
