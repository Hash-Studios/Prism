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
