CLASS lhc_Travel DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    CONSTANTS:
      BEGIN OF travel_status,
        open     TYPE c LENGTH 1 VALUE 'O', "Open
        accepted TYPE c LENGTH 1 VALUE 'A', "Accepted
        rejected TYPE c LENGTH 1 VALUE 'X', "Rejected
      END OF travel_status.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Travel RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Travel RESULT result.

    METHODS setTravelNumber FOR DETERMINE ON SAVE
      IMPORTING keys FOR Travel~setTravelNumber.
    METHODS setStatusToOpen FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Travel~setStatusToOpen.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Travel RESULT result.

    METHODS acceptTravel FOR MODIFY
      IMPORTING keys FOR ACTION Travel~acceptTravel RESULT result.

    METHODS rejectTravel FOR MODIFY
      IMPORTING keys FOR ACTION Travel~rejectTravel RESULT result.

    METHODS validateDates FOR VALIDATE ON SAVE
      IMPORTING keys FOR Travel~validateDates.

    METHODS validateAgency FOR VALIDATE ON SAVE
      IMPORTING keys FOR Travel~validateAgency.

    METHODS validateCustomer FOR VALIDATE ON SAVE
      IMPORTING keys FOR Travel~validateCustomer.

    METHODS deductDiscount FOR MODIFY
      IMPORTING keys FOR ACTION Travel~deductDiscount RESULT result.

    METHODS reCalcTotalPrice FOR MODIFY
      IMPORTING keys FOR ACTION Travel~reCalcTotalPrice.
    METHODS calculateTotalPrice FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Travel~calculateTotalPrice.
    METHODS GetDefaultsForDeductDiscount FOR READ
      IMPORTING keys FOR FUNCTION Travel~GetDefaultsForDeductDiscount RESULT result.

ENDCLASS.

CLASS lhc_Travel IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD setTravelNumber.

    READ ENTITIES OF zr_flight_jp_3 IN LOCAL MODE
        ENTITY traveL
        FIELDS ( TravelID )
        WITH CORRESPONDING #( keys )
    RESULT DATA(travels).

    DELETE travels WHERE TravelID IS NOT INITIAL.
    CHECK travels IS NOT INITIAL.

    SELECT SINGLE FROM /dmo/a_travel_d FIELDS MAX( travel_id ) INTO @DATA(max_travel_id).

    "update involved instances"
    MODIFY ENTITIES OF zr_flight_jp_3 IN LOCAL MODE
        ENTITY Travel
        UPDATE FIELDS ( TravelID )
        WITH VALUE #( FOR travel IN travels INDEX INTO i (
                              %tky = travel-%tky
                              TravelID = max_travel_id + i
        ) ).

  ENDMETHOD.

  METHOD setStatusToOpen.
    READ ENTITIES OF zr_flight_jp_3 IN LOCAL MODE
        ENTITY traveL
        FIELDS ( OverallStatus )
        WITH CORRESPONDING #( keys )
    RESULT DATA(travels).

    DELETE travels WHERE OverallStatus IS NOT INITIAL.
    CHECK travels IS NOT INITIAL.

    "update involved instances"
    MODIFY ENTITIES OF zr_flight_jp_3 IN LOCAL MODE
        ENTITY Travel
        UPDATE FIELDS ( OverallStatus )
        WITH VALUE #( FOR travel IN travels (
                              %tky = travel-%tky
                              OverallStatus = travel_status-open
        ) ).

  ENDMETHOD.

  METHOD get_instance_features.
  ENDMETHOD.

  METHOD acceptTravel.

    MODIFY ENTITIES OF zr_flight_jp_3 IN LOCAL MODE
        ENTITY Travel
        UPDATE FIELDS ( OverallStatus )
        WITH VALUE #( FOR key IN keys (
                              %tky = key-%tky
                              OverallStatus = travel_status-accepted
        ) ).

    READ ENTITIES OF zr_flight_jp_3 IN LOCAL MODE
        ENTITY travel
        FIELDS ( OverallStatus )
        WITH CORRESPONDING #( keys )
     RESULT DATA(travels).

    result = VALUE #( FOR travel IN travels (
                              %tky = travel-%tky
                              %param = travel ) ).

  ENDMETHOD.

  METHOD rejectTravel.

    MODIFY ENTITIES OF zr_flight_jp_3 IN LOCAL MODE
          ENTITY Travel
          UPDATE FIELDS ( OverallStatus )
          WITH VALUE #( FOR key IN keys (
                                %tky = key-%tky
                                OverallStatus = travel_status-rejected
          ) ).

    READ ENTITIES OF zr_flight_jp_3 IN LOCAL MODE
        ENTITY travel
        FIELDS ( OverallStatus )
        WITH CORRESPONDING #( keys )
     RESULT DATA(travels).

    result = VALUE #( FOR travel IN travels (
                             %tky = travel-%tky
                             %param = travel ) ).

  ENDMETHOD.

  METHOD validateDates.

    READ ENTITIES OF zr_flight_jp_3 IN LOCAL MODE
        ENTITY traveL
        FIELDS ( BeginDate EndDate )
        WITH CORRESPONDING #( keys )
     RESULT DATA(travels).

    LOOP AT travels INTO DATA(travel).

      APPEND VALUE #(  %tky               = travel-%tky
                         %state_area        = 'VALIDATE_DATES' ) TO reported-travel.

      IF travel-BeginDate IS INITIAL.

        APPEND VALUE #( %tky = travel-%tky ) TO failed-travel.

        APPEND VALUE #( %tky               = travel-%tky
                        %state_area        = 'VALIDATE_DATES'
                         %msg              = NEW /dmo/cm_flight_messages(
                                                                textid   = /dmo/cm_flight_messages=>enter_begin_date
                                                                severity = if_abap_behv_message=>severity-error )
                        %element-BeginDate = if_abap_behv=>mk-on ) TO reported-travel.

      ENDIF.

      IF travel-EndDate IS INITIAL.

        APPEND VALUE #( %tky = travel-%tky ) TO failed-travel.

        APPEND VALUE #( %tky               = travel-%tky
                        %state_area        = 'VALIDATE_DATES'
                         %msg              = NEW /dmo/cm_flight_messages(
                                                                textid   = /dmo/cm_flight_messages=>enter_end_date
                                                                severity = if_abap_behv_message=>severity-error )
                        %element-BeginDate = if_abap_behv=>mk-on ) TO reported-travel.
      ENDIF.


      IF travel-EndDate < travel-BeginDate AND travel-BeginDate IS NOT INITIAL
                                           AND travel-EndDate IS NOT INITIAL.

        APPEND VALUE #( %tky = travel-%tky ) TO failed-travel.

        APPEND VALUE #( %tky               = travel-%tky
                        %state_area        = 'VALIDATE_DATES'
                         %msg              = NEW /dmo/cm_flight_messages(
                                                                textid   = /dmo/cm_flight_messages=>begin_date_bef_end_date
                                                                begin_date = travel-BeginDate
                                                                end_date   = travel-EndDate
                                                                severity = if_abap_behv_message=>severity-error )
                        %element-BeginDate = if_abap_behv=>mk-on ) TO reported-travel.

      ENDIF.


      IF travel-BeginDate < cl_abap_context_info=>get_system_date( ) AND travel-BeginDate IS NOT INITIAL.

        APPEND VALUE #( %tky = travel-%tky ) TO failed-travel.

        APPEND VALUE #( %tky               = travel-%tky
                        %state_area        = 'VALIDATE_DATES'
                         %msg              = NEW /dmo/cm_flight_messages(
                                                                begin_date = travel-BeginDate
                                                                textid   = /dmo/cm_flight_messages=>begin_date_on_or_bef_sysdate
                                                                severity = if_abap_behv_message=>severity-error )
                        %element-BeginDate = if_abap_behv=>mk-on ) TO reported-travel.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

  METHOD validateAgency.

    READ ENTITIES OF zr_flight_jp_3 IN LOCAL MODE
        ENTITY traveL
        FIELDS ( AgencyID )
        WITH CORRESPONDING #( keys )
     RESULT DATA(travels).

    LOOP AT travels INTO DATA(travel).

      APPEND VALUE #(  %tky               = travel-%tky
                         %state_area        = 'VALIDATE_AGENCY' ) TO reported-travel.

      IF travel-AgencyID IS INITIAL.

        APPEND VALUE #( %tky = travel-%tky ) TO failed-travel.

        APPEND VALUE #( %tky               = travel-%tky
                        %state_area        = 'VALIDATE_AGENCY'
                         %msg              = NEW /dmo/cm_flight_messages(
                                                                textid   = /dmo/cm_flight_messages=>enter_agency_id
                                                                severity = if_abap_behv_message=>severity-error )
                        %element-AgencyID = if_abap_behv=>mk-on ) TO reported-travel.

      ENDIF.

    ENDLOOP.
  ENDMETHOD.

  METHOD validateCustomer.

    READ ENTITIES OF zr_flight_jp_3 IN LOCAL MODE
        ENTITY traveL
        FIELDS ( CustomerID )
        WITH CORRESPONDING #( keys )
     RESULT DATA(travels).

    DATA customers TYPE SORTED TABLE OF /dmo/customer WITH UNIQUE KEY customer_id.

    " Optimization of DB select: extract distinct non-initial customer IDs
    customers = CORRESPONDING #( travels DISCARDING DUPLICATES MAPPING customer_id = CustomerID EXCEPT * ).
    DELETE customers WHERE customer_id IS INITIAL.

    IF  customers IS NOT INITIAL.
      " Check if customer ID exists
      SELECT FROM /dmo/customer FIELDS customer_id
                                FOR ALL ENTRIES IN @customers
                                WHERE customer_id = @customers-customer_id
      INTO TABLE @DATA(valid_customers).
    ENDIF.

    LOOP AT travels INTO DATA(travel).

      APPEND VALUE #(  %tky               = travel-%tky
                         %state_area        = 'VALIDATE_CUSTOMER' ) TO reported-travel.

      IF travel-CustomerID IS INITIAL.

        APPEND VALUE #( %tky = travel-%tky ) TO failed-travel.

        APPEND VALUE #( %tky               = travel-%tky
                        %state_area        = 'VALIDATE_CUSTOMER'
                         %msg              = NEW /dmo/cm_flight_messages(
                                                                textid   = /dmo/cm_flight_messages=>enter_customer_id
                                                                severity = if_abap_behv_message=>severity-error )
                        %element-CustomerID = if_abap_behv=>mk-on ) TO reported-travel.

      ELSEIF travel-CustomerID IS NOT INITIAL AND NOT line_exists( valid_customers[ customer_id = travel-CustomerID ] ).
        APPEND VALUE #(  %tky = travel-%tky ) TO failed-travel.

        APPEND VALUE #(  %tky                = travel-%tky
                         %state_area         = 'VALIDATE_CUSTOMER'
                         %msg                = NEW /dmo/cm_flight_messages(
                                                                customer_id = travel-customerid
                                                                textid      = /dmo/cm_flight_messages=>customer_unkown
                                                                severity    = if_abap_behv_message=>severity-error )
                         %element-CustomerID = if_abap_behv=>mk-on
                      ) TO reported-travel.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD deductDiscount.
    DATA travels_for_update TYPE TABLE FOR UPDATE zr_flight_jp_3.
    DATA(keys_with_valid_discount) = keys.

    LOOP AT keys_with_valid_discount ASSIGNING FIELD-SYMBOL(<key_with_valid_discount>)
                                              WHERE %param-discount_percent IS INITIAL
                                              OR %param-discount_percent < 0
                                              OR %param-discount_percent > 100.
      APPEND VALUE #( %tky = <key_with_valid_discount>-%tky ) TO failed-travel.

      APPEND VALUE #( %tky               = <key_with_valid_discount>-%tky
                      %state_area        = 'DEDUCT_DISCOUNT'
                       %msg              = NEW /dmo/cm_flight_messages(
                                                              textid   = /dmo/cm_flight_messages=>discount_invalid
                                                              severity = if_abap_behv_message=>severity-error )
                      %element-TotalPrice = if_abap_behv=>mk-on
                      %op-%action-deductDiscount = if_abap_behv=>mk-off ) TO reported-travel.

      DELETE keys_with_valid_discount.
    ENDLOOP.

    CHECK keys_with_valid_discount IS NOT INITIAL.

    READ ENTITIES OF zr_flight_jp_3 IN LOCAL MODE
        ENTITY traveL
        FIELDS ( BookingFee )
        WITH CORRESPONDING #( keys_with_valid_discount )
     RESULT DATA(travels).

    LOOP AT Travels ASSIGNING FIELD-SYMBOL(<travel>).
      DATA percentage TYPE decfloat16.
      DATA(discount_percentage) = keys_with_valid_discount[ KEY id %tky = <travel>-%tky ]-%param-discount_percent.
      percentage = discount_percentage / 100.
      DATA(reduced_fee) = <travel>-BookingFee * ( 1 - percentage ) .

      APPEND VALUE #( %tky       = <travel>-%tky
                      BookingFee = reduced_fee
                    ) TO travels_for_update.
    ENDLOOP.

    MODIFY ENTITIES OF zr_flight_jp_3 IN LOCAL MODE
        ENTITY Travel
        UPDATE FIELDS ( BookingFee )
        WITH travels_for_update.

    READ ENTITIES OF zr_flight_jp_3 IN LOCAL MODE
        ENTITY travel
        ALL FIELDS WITH
        CORRESPONDING #( travels )
     RESULT DATA(travel_with_discount).

    result = VALUE #( FOR travel IN travel_with_discount (
                             %tky = travel-%tky
                             %param = travel ) ).

  ENDMETHOD.

  METHOD reCalcTotalPrice.

    TYPES: BEGIN OF ty_amount_per_currencycode,
             amount        TYPE /dmo/total_price,
             currency_code TYPE /dmo/currency_code,
           END OF ty_amount_per_currencycode.

    DATA: amount_per_currencycode TYPE STANDARD TABLE OF ty_amount_per_currencycode.

    READ ENTITIES OF zr_flight_jp_3 IN LOCAL MODE
        ENTITY traveL
        FIELDS ( BookingFee )
        WITH CORRESPONDING #( keys )
     RESULT DATA(travels).

    LOOP AT travels ASSIGNING FIELD-SYMBOL(<travel>).

      amount_per_currencycode = VALUE #( ( amount = <travel>-BookingFee
                                           currency_code = <travel>-CurrencyCode ) ).

*      READ ENTITIES OF zr_flight_jp_3 IN LOCAL MODE
*          ENTITY Travel BY \_Booking
*             FIELDS ( FlightPrice CurrencyCode )
*          WITH VALUE #( ( %tky = <travel>-%tky ) )
*          RESULT DATA(bookings).
*
*      LOOP AT bookings ASSIGNING FIELD-SYMBOL(<booking>) WHERE CurrencyCode IS NOT INITIAL.
*        COLLECT VALUE ty_amount_per_currencycode(
*                  amount        = <booking>-FlightPrice
*                  currency_code = <booking>-CurrencyCode ) INTO amount_per_currencycode.
*      ENDLOOP.
*
*      READ ENTITIES OF zr_flight_jp_3 IN LOCAL MODE
*          ENTITY Bookings BY \_BookingSupplement
*             FIELDS ( BookingSupplementPrice CurrencyCode )
*          WITH VALUE #( FOR rba_booking IN bookings ( %tky = rba_booking-%tky ) )
*          RESULT DATA(booking_supplements).
*
*      LOOP AT booking_supplements ASSIGNING FIELD-SYMBOL(<booking_supplement>) WHERE CurrencyCode IS NOT INITIAL.
*        COLLECT VALUE ty_amount_per_currencycode(
*                  amount        = <booking_supplement>-BookSupplPrice
*                  currency_code = <booking_supplement>-CurrencyCode ) INTO amount_per_currencycode.
*      ENDLOOP.
*
*      CLEAR <travel>-TotalPrice.
*      LOOP AT amount_per_currencycode ASSIGNING FIELD-SYMBOL(<amount_per_currencycode>).
*        IF single
*     ENDLOOP.
    ENDLOOP.

  ENDMETHOD.

  METHOD calculateTotalPrice.

    MODIFY ENTITIES OF zr_flight_jp_3 IN LOCAL MODE
        ENTITY Travel
        EXECUTE reCalcTotalPrice
        FROM CORRESPONDING #( keys ).

  ENDMETHOD.

  METHOD GetDefaultsForDeductDiscount.

    LOOP AT keys INTO DATA(key).
      INSERT VALUE #( %tky = key-%tky ) INTO TABLE result REFERENCE INTO DATA(new_line).


      new_line->%param-PercentUnit = '%'.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
