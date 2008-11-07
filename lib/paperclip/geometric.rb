module Paperclip
  # Geometry methods shared between Geometry and Attachment.
  module Geometric

    # True if the dimensions represent a square
    def square?
      height == width
    end

    # True if the dimensions represent a horizontal rectangle
    def horizontal?
      height < width
    end

    # True if the dimensions represent a vertical rectangle
    def vertical?
      height > width
    end

    # The aspect ratio of the dimensions.
    def aspect
      width / height
    end

    # Returns the larger of the two dimensions
    def larger
      [height, width].max
    end

    # Returns the smaller of the two dimensions
    def smaller
      [height, width].min
    end

  end
end
