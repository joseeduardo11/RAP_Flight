@EndUserText.label: 'Abstract Entity for Deducting Discount'
define root abstract entity ZA_Travel_Discount_JP
{
  @Semantics.quantity.unitOfMeasure: 'PercentUnit'
  discount_percent : /DMO/BT_DiscountPercentage;
  @Semantics.unitOfMeasure
  PercentUnit      : abap.unit;

//  @Semantics.amount.currencyCode: 'CurrencyCode'
//  NetAmount        : abap.curr(15,2);
//
//  @Semantics.currencyCode
//  @Consumption.valueHelpDefinition: [{entity: {name: 'I_CurrencyStdVH', element: 'Currency' }, useForValidation: true }]
//  CurrencyCode     : abap.cuky;

}
