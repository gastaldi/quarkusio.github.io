require 'chunky_png'
require 'cairo'
require 'rsvg2'

module Jekyll
  # Generates social images for blog posts and guides
  module SocialImages
    def social_image(text, page_path)
      # If text is not empty, return it
      if text.nil? || text.empty?
        # If page_path contains "guides/", return the social image path
        if page_path.include?('guides/')
          return "/assets/images/social/#{File.basename(page_path, '.adoc')}.png"
        else
          return "/assets/images/quarkus_card.png"
        end
      else
        text
      end
    end
  end

  class GenerateSocialImagesGenerator < Generator
    def generate(site)
      guides = Dir.glob(File.join(site.source, '_guides', '*.adoc'))
      output_dir = 'assets/images/social'
      FileUtils.mkdir_p(File.join(site.dest, output_dir))

      guides.each do |guide_file|
        basename = File.basename(guide_file, '.adoc')
        if basename.start_with?('_')
          next
        end
        title = extract_title(guide_file)
        output_file = File.join(site.dest, output_dir, "#{basename}.png")
        # Skip if the file already exists
        if File.exist?(output_file)
          next
        end

        # Generate the SVG image
        svg_image_str = generate_svg_string(title)

        # Create a Cairo surface and context for the PNG image (must be smaller than 600x330)
        surface = Cairo::ImageSurface.new(Cairo::FORMAT_ARGB32, 600, 250)
        context = Cairo::Context.new(surface)

        # Load and render the SVG onto the Cairo context
        svg = RSVG::Handle.new_from_data(svg_image_str)
        context.render_rsvg_handle(svg)

        # Save the Cairo surface to a PNG file
        b = StringIO.new
        surface.write_to_png(b)

        # Compose the generated image with the template image
        png_image = ChunkyPNG::Image.from_file('_plugins/assets/quarkus_card_blank.png')
        # Change the last parameters to change the position of the generated image
        png_image.compose!(ChunkyPNG::Image.from_blob(b.string), 0, 80)

        Jekyll.logger.info("Generating social image to #{output_file}")
        # Save the composed image to the output file
        png_image.save(output_file)
      end
    end

    def split_text_into_lines(text)
      lines = []
      words = text.split(' ')
      current_line = ''

      words.each do |word|
        if current_line.length + word.length <= 32
          current_line += (current_line == '' ? '' : ' ') + word
        else
          lines.push(current_line)
          current_line = word
        end
      end

      lines.push(current_line) unless current_line.empty?

      lines
    end

    private

    def generate_svg_string(title)
      idx = 90
      font_size = 30
      tspan_elements = ''
      split_text_into_lines(title).each_with_index do |line, index|
        tspan_elements += "<tspan x='50%' y='#{idx}'>#{line}</tspan>"
        idx += font_size + 10
      end
      "
        <svg width=\"600\" height=\"330\">
          <style>
            .title { fill: white; font-size: #{font_size}px; font-weight: bold; font-family:'Open Sans'}
          </style>
          <text x=\"50%\" y=\"50%\" text-anchor=\"middle\" class=\"title\" >
              #{tspan_elements}
          </text>
        </svg>
      "
    end

    def extract_title(adoc_file)
      title = ''
      File.open(adoc_file, 'r') do |file|
        file.each_line do |line|
          if line.start_with? '='
            title = line[2..].strip
            break
          end
        end
      end
      title
    end
  end
end

Liquid::Template.register_filter(Jekyll::SocialImages)
