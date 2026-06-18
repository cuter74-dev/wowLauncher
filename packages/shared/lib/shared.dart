/// Public API of the `shared` package.
///
/// Contains the common models, API DTOs and small utilities that are used by
/// both the desktop agent and the mobile app so the two sides always agree on
/// the wire format.
library shared;

// Models
export 'src/models/launch_app.dart';
export 'src/models/app_list_item.dart';
export 'src/models/paired_device.dart';
export 'src/models/launch_log.dart';

// DTOs (request/response payloads)
export 'src/dto/health_response.dart';
export 'src/dto/pairing_payload.dart';
export 'src/dto/pair_request.dart';
export 'src/dto/pair_status.dart';
export 'src/dto/launch_response.dart';

// Utilities
export 'src/util/api_paths.dart';
export 'src/util/json_utils.dart';
