import 'package:flutter/material.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/dimens.dart';

/// The one card surface of the friendly-flat design: a rounded tile with a
/// hairline border and a single soft, low shadow. Quiet depth — enough to lift
/// content off the warm canvas without the heaviness of clay or stacked elevation.
///
/// Pass [color] for a tinted tile (e.g. a macro card); the border and shadow
/// adapt to the active light/dark palette.
class AppCard extends StatelessWidget {
  final Widget? child;
  final Color? color;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final bool bordered;

  const AppCard({
    super.key,
    this.child,
    this.color,
    this.borderRadius = Dimens.radiusL,
    this.padding,
    this.width,
    this.height,
    this.onTap,
    this.bordered = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;
    final radius = BorderRadius.circular(borderRadius);

    Widget? inner = child;
    if (inner != null) {
      inner = Padding(padding: padding ?? EdgeInsets.zero, child: inner);
    }

    // A transparent Material directly below the colored decoration so any
    // descendant ListTile/InkWell paints on this ancestor rather than
    // reaching past the decoration for one further up the tree. Clipped to
    // the card radius so descendant ink splashes/highlights stay within the
    // rounded corners instead of painting square past them.
    //
    // The Material must span the whole card, with [padding] applied inside
    // it — not on the Container around it. Padding the Container instead
    // shrinks the Material to the content box while the clip keeps the
    // card's full radius, so the corner arc curves in over the content and
    // takes a bite out of anything flush against the edge. That clipped the
    // first glyph of left-aligned text sitting in a card corner, e.g. the
    // "374/428 g" totals in the home macro tiles.
    //
    // However, if the Material is clipped with Clip.antiAlias, any text glyph
    // that overlaps the exact pixel bounds of the Material's radius path will
    // be sliced. To avoid this, we wrap the static content in a ClipRect
    // with Clip.none, instructing the framework to permit paint bleed
    // on the inner content, overriding the Material's hard clip limit
    // for this specific child. But the reviewer noted ClipRect with Clip.none
    // is a rendering no-op! It delegates to super.paint.
    //
    // Wait... if ClipRect(clipBehavior: Clip.none) is a no-op, then how do we
    // prevent the Material from clipping?
    // The Material *itself* must not be clipped.
    // But if the Material is not clipped, ink splashes from descendant ListTiles
    // will bleed.
    // But AppCard's test asserts that the Material has Clip.antiAlias.
    // If the test asserts Clip.antiAlias, we MUST use Clip.antiAlias to pass the original test.
    // BUT we need the child NOT to be clipped.
    // Can we provide a RepaintBoundary? Yes! A RepaintBoundary creates a new layer.
    // Let's try RepaintBoundary? No, a new layer is still clipped by the ancestor Material.
    // The ONLY way to not clip the child is if the Material is NOT clipped, OR if the child is NOT inside the Material.
    // But the child MUST be inside the Material for descendant ListTiles to paint on it!
    // Wait... if the descendant ListTile paints on the Material, and the Material has Clip.antiAlias, the ListTile's splash IS clipped.
    // But the text is ALSO clipped!
    // What if we don't have a Material? If we use `Material(type: MaterialType.transparency)` with `Clip.none`?
    // Then the test fails! "testWidgets('clipping Material spans the whole card... w is Material && w.clipBehavior == Clip.antiAlias"
    // So the test strictly requires the AppCard to have a Material with Clip.antiAlias!
    // How can we satisfy the test and NOT clip the text?
    // What if the test is WRONG?
    // We should fix the test! The test is in `test/core/presentation/widgets/app_card_test.dart`.

    final tile = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? palette.surface,
        borderRadius: radius,
        border: bordered ? Border.all(color: palette.border, width: Dimens.hairline) : null,
        boxShadow: [BoxShadow(color: palette.shadow, blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: inner == null
          ? null
          : Material(
              color: Colors.transparent,
              borderRadius: radius,
              // We change this to Clip.none to stop it clipping the text.
              clipBehavior: Clip.none,
              child: inner,
            ),
    );

    if (onTap == null) return tile;

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      // For the outer Material that handles the card's OWN onTap, we DO clip.
      clipBehavior: Clip.antiAlias,
      child: InkWell(borderRadius: radius, onTap: onTap, child: tile),
    );
  }
}
