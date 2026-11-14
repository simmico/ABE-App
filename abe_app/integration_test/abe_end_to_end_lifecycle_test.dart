import 'package:integration_test/integration_test.dart';

import '../test/end_to_end_lifecycle_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerAbeLifecycleE2eTests();
}
