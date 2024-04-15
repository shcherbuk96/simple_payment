import 'package:freezed_annotation/freezed_annotation.dart';

part 'product_model.freezed.dart';

// enum ProductPeriod {
//   day,
//   month,
//   year,
// }

@freezed
class ProductModel with _$ProductModel {
  const factory ProductModel({
    required String id,
    required String price,
    required String currencyCode,
    required String currencySymbol,
    required String description,
    required String title,
    required double rawPrice,
    // required String countryCode,
    // required ProductPeriod period,
    // required int numberOfPeriod,
    // required int subscriptionGroupId,
  }) = _ProductModel;
}
