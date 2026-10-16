import 'package:flutter/material.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/ally-logo-v2.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
    filterQuality: FilterQuality.medium,
  );
}

class BrandBanner extends StatelessWidget {
  const BrandBanner({super.key, this.width = 180});
  final double width;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'ALLY Agents',
    image: true,
    // Remove transparent outer padding in the layout without changing the file.
    child: ClipRect(
      child: Align(
        widthFactor: 0.9,
        heightFactor: 0.66,
        child: Image.asset(
          'assets/images/ally-banner-v3.png',
          width: width / 0.9,
          height: width / 0.9 / 2,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
          filterQuality: FilterQuality.medium,
        ),
      ),
    ),
  );
}
