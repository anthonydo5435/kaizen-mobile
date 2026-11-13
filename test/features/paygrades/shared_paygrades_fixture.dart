Map<String, dynamic> sharedPaygradesJson({bool includesPayRates = true}) => {
  'view_type': 'paygrades',
  'content': {
    'title': 'P-ORG Dept Lead (Copy)-1',
    'department_name': 'P-ORG-DEPT',
    'paygrade_unit': 'hr',
    'includes_pay_rates': includesPayRates,
    'primary': [
      {
        'title': 'A1',
        'level': 1,
        'description': 'Primary responsibilities',
        'promotion_requirement': 'Complete training',
        'pay_rate': '90.00',
      },
      {
        'title': 'Mangement',
        'level': 2,
        'description': '',
        'promotion_requirement': '',
        'pay_rate': '100.00',
      },
      {
        'title': 'pol',
        'level': 3,
        'description': '',
        'promotion_requirement': '',
        'pay_rate': '786.00',
      },
    ],
    'ancillary': [
      {
        'title': 'Mangement',
        'level': 1,
        'description': '',
        'promotion_requirement': '',
        'pay_rate': '50.00',
      },
    ],
  },
};
