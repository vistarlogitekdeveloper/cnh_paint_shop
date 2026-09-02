/// Vistar Premium design system — single import for screens.
///
/// A screen imports this one file and gets the tokens, the theme extension
/// (`context.v`), and every component. Nothing outside `lib/design/` should
/// import the individual component files.
library;

export 'brand_assets.dart';
export 'components/ambient_background.dart';
export 'components/loaders.dart';
export 'components/v_button.dart';
export 'components/v_card.dart';
export 'components/v_input.dart';
export 'components/v_page.dart';
export 'components/v_pill.dart';
export 'components/v_shimmer.dart';
export 'components/v_states.dart';
export 'components/v_table.dart';
export 'components/v_toast.dart';
export 'theme.dart';
export 'tokens.dart';
export 'typography.dart';
