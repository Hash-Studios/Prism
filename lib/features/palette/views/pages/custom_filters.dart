import 'package:photofilters/filters/color_filters.dart';
import 'package:photofilters/filters/image_filters.dart';
import 'package:photofilters/filters/subfilters.dart';
import 'package:photofilters/utils/convolution_kernels.dart';

class InvertFilter extends ColorFilter {
  InvertFilter() : super(name: "Invert") {
    subFilters.add(InvertSubFilter());
  }
}

class BlurFilter extends ImageFilter {
  BlurFilter() : super(name: "Blur") {
    subFilters.add(ConvolutionSubFilter.fromKernel(
      guassian7x7Kernel,
    ));
  }
}

class SharpenFilter extends ImageFilter {
  SharpenFilter() : super(name: "Sharpen") {
    subFilters.add(ConvolutionSubFilter.fromKernel(
      sharpenKernel,
    ));
  }
}

class EdgeDetectionFilter extends ImageFilter {
  EdgeDetectionFilter() : super(name: "Edge") {
    subFilters.add(ConvolutionSubFilter.fromKernel(
      edgeDetectionHardKernel,
    ));
  }
}

class EmbossFilter extends ImageFilter {
  EmbossFilter() : super(name: "Emboss") {
    subFilters.add(ConvolutionSubFilter.fromKernel(
      embossKernel,
    ));
  }
}

class BlurMaxFilter extends ImageFilter {
  BlurMaxFilter() : super(name: "Blur Max") {
    subFilters.add(ConvolutionSubFilter.fromKernel(
      blurKernel,
    ));
    subFilters.add(ConvolutionSubFilter.fromKernel(
      blurKernel,
    ));
    subFilters.add(ConvolutionSubFilter.fromKernel(
      blurKernel,
    ));
    subFilters.add(ConvolutionSubFilter.fromKernel(
      blurKernel,
    ));
  }
}

class MeanFilter extends ImageFilter {
  MeanFilter() : super(name: "Mean") {
    subFilters.add(ConvolutionSubFilter.fromKernel(
      mean5x5Kernel,
    ));
  }
}

class HighPassFilter extends ImageFilter {
  HighPassFilter() : super(name: "High Pass") {
    subFilters.add(ConvolutionSubFilter.fromKernel(
      highPass3x3Kernel,
    ));
  }
}

class LowPassFilter extends ImageFilter {
  LowPassFilter() : super(name: "Low Pass") {
    subFilters.add(ConvolutionSubFilter.fromKernel(
      lowPass5x5Kernel,
    ));
  }
}
