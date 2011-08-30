module Paperclip

  # Defines the geometry of an image.
  class Geometry
    include Paperclip::Geometric
    attr_accessor :height, :width, :modifier

    # Gives a Geometry representing the given height and width
    def initialize width = nil, height = nil, modifier = nil
      @height = height.to_f
      @width  = width.to_f
      @modifier = modifier
    end

    # Uses ImageMagick to determing the dimensions of a file, passed in as either a
    # File or path.
    def self.from_file file
      file = file.path if file.respond_to? "path"
      raise(Paperclip::NotIdentifiedByImageMagickError.new("Cannot find the geometry of a file with a blank name")) if file.blank?
      geometry = begin
                   Paperclip.run("identify", "-format %wx%h :file", :file => "#{file}[0]")
                 rescue Cocaine::ExitStatusError
                   ""
                 rescue Cocaine::CommandNotFoundError => e
                   raise Paperclip::CommandNotFoundError.new("Could not run the `identify` command. Please install ImageMagick.")
                 end
      parse(geometry) ||
        raise(NotIdentifiedByImageMagickError.new("#{file} is not recognized by the 'identify' command."))
    end

    # Parses a "WxH" formatted string, where W is the width and H is the height.
    def self.parse string
      if match = (string && string.match(/\b(\d*)x?(\d*)\b([\>\<\#\@\%^!])?/i))
        Geometry.new(*match[1,3])
      end
    end

    # Returns the width and height in a format suitable to be passed to Geometry.parse
    def to_s
      s = ""
      s << width.to_i.to_s if width > 0
      s << "x#{height.to_i}" if height > 0
      s << modifier.to_s
      s
    end

    # Same as to_s
    def inspect
      to_s
    end

    # Returns the scaling and cropping geometries (in string-based ImageMagick format)
    # neccessary to transform this Geometry into the Geometry given. If crop is true,
    # then it is assumed the destination Geometry will be the exact final resolution.
    # In this case, the source Geometry is scaled so that an image containing the
    # destination Geometry would be completely filled by the source image, and any
    # overhanging image would be cropped. Useful for square thumbnail images. The cropping
    # is weighted at the center of the Geometry.
    def transformation_to dst, crop = false
      if crop
        ratio = Geometry.new( dst.width / self.width, dst.height / self.height )
        scale_geometry, scale = scaling(dst, ratio)
        crop_geometry         = cropping(dst, ratio, scale)
      else
        scale_geometry        = dst.to_s
      end

      [ scale_geometry, crop_geometry ]
    end
    
    # Adapted from attachment_fu.
    # Attempts to get new dimensions for the current geometry string given these old dimensions.
    # This doesn't implement the aspect flag (!) or the area flag (@).  PDI
    def new_dimensions_for(orig_width, orig_height)
      new_width  = orig_width
      new_height = orig_height

      case self.modifier
        when '#'
          new_width  = self.width
          new_height = self.height
        when '%'
          scale_x = self.width.zero?  ? 100 : self.width
          scale_y = self.height.zero? ? self.width : self.height
          new_width    = scale_x.to_f * (orig_width.to_f  / 100.0)
          new_height   = scale_y.to_f * (orig_height.to_f / 100.0)
        when '<', '>', nil
          scale_factor =
            if new_width.zero? || new_height.zero?
              1.0
            else
              if self.width.nonzero? && self.height.nonzero?
                [self.width.to_f / new_width.to_f, self.height.to_f / new_height.to_f].min
              else
                self.width.nonzero? ? (self.width.to_f / new_width.to_f) : (self.height.to_f / new_height.to_f)
              end
            end
          new_width  = scale_factor * new_width.to_f
          new_height = scale_factor * new_height.to_f
          new_width  = orig_width  if self.modifier && new_width.send(self.modifier,  orig_width)
          new_height = orig_height if self.modifier && new_height.send(self.modifier, orig_height)
      end

      [new_width, new_height].collect! { |v| [v.round, 1].max }
    end

    private

    def scaling dst, ratio
      if ratio.horizontal? || ratio.square?
        [ "%dx" % dst.width, ratio.width ]
      else
        [ "x%d" % dst.height, ratio.height ]
      end
    end

    def cropping dst, ratio, scale
      if ratio.horizontal? || ratio.square?
        "%dx%d+%d+%d" % [ dst.width, dst.height, 0, (self.height * scale - dst.height) / 2 ]
      else
        "%dx%d+%d+%d" % [ dst.width, dst.height, (self.width * scale - dst.width) / 2, 0 ]
      end
    end
  end
end
