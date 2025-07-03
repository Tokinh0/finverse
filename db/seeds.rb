CATEGORIES_WITH_KEYWORDS = {
  # category => [{subcategories => [keywords]}, subcategories => [keywords]...]
  earnings: [{
    'SALARIO': ['SALARIO', 'LIBERACAO_CAMBIO', 'LIBERACAO_CAMBIO_BANCO_LIQUIDACAO_CONTR'],
    'TRANSFERENCIAS': ['TRANSFERENCIA_DA_POUPANCA'],
    'OUTROS': ['DISTRIBUICAO', 'RECEBIMENTO'],
  }],
  investments: [{
    'POUPANCA': ['APLICACAO'],
    'TRANSFERENCIA': ['PAGAMENTO_PIX_00000000191'],
  }],
  confort: [{
    'FOOD': [
      'IFOOD',
      'IFD',
      'RESTAURANT_A',
      'RESTAURANT_B',
      'RESTAURANT_C',
      'FOOD_VENDOR',
      'PANIFICADORA',
      'MC_DONALDS',
      'RESTAURANT_D',
    ],
    'UBER': ['UBER'],
    'ASSINATURA': [
      'NETFLIX',
      'SPOTIFY',
      'AMAZON_PRIME','AMAZONPRIME',
      'DISNEY',
      'APPLE',
      'VIACOM',
      'MELIMAIS',
      'PARAMOUNT'
    ]
  }],
  sporadic_expenses: [{
    'BEM_ESTAR': ['PHARMACY'],
    'KIDS': [
      'SCHOOL_PAYEE', # school
      'BRINQUEDOS',
      'PAPELARIA',
    ],
    'CASA': [
      'PAGAMENTO_PIX_00000000000191', # MANUTENÇÃO AR CONDICIONADO
    ],
  }],
  fixed_expenses: [{
    'CONTAS': [
      'PERSON_A',
      'HEALTH_PLAN',
      'POWER_COMPANY',
      'SEG_VIDA',
      'ACCOUNTANT_LTDA', 'ACCOUNTANT_OFFICE', # CONTADOR
      'INTERNET_PROVIDER', # Internet
    ],
    'TAXAS': [
      'TAXA',
      'ANUIDADE_CARTAO',
      'TARIFA',
      'IOF',
      'DEBITO_DE_CAMBIO',
      'CESTA_DE', # Cesta de relacionamento sicredi,
      'MENSALID_TAG_DE_PASSAGEM',
      'INTEGR.CAPITAL_SUBSCRITO' # Taxa de alguma coisa do sicredi TODO: revisar
    ],
    'IMPOSTOS': [
      'DEPARTAMENTO_ESTADU', #IPVA
      'MINISTERIO_DA_FAZEN',
      'RECEITA_FEDERAL',
    ],
    'CARRO': [
      'POSTO',
      'CENTRO_AUTOMOTIVO',
      'AUTOMOTIVO',
      'PEDAGIO',
      'ESTACIONAMENTO',
      'CAR_INSURANCE',
      'CAR_WASH' # LAVAGEM
    ],
    'MERCADO': ['MARKET_C', 'MARKET_D', 'MARKET_E', 'MARKET_G'],
    'BEM_ESTAR': [
      'GYM_B',
      'PÉRICLES_RODRIGUES',
      'SACOLAO',
      'HORTIFRUTI',
      'GYM_A_PARCEL', 'GYM_A', '00000000000272',
      'HAIRDRESSER' # haircut
    ],
    'ASSINATURA': ['GPT']
  }],
  pleasure: [{
    'ALCOOL': [
      'DISTRIBUIDORA',
      'BEBIDA',
      'TABACARIA',
      'BAR',
      'BAR_A',
      'BAR_B',
      'RESTAURAN',
      'BAR_C',
      'MARKET_A', # neighborhood market
      'LIQUOR_STORE_C', # liquor store,
      'LIQUOR_STORE_B', # liquor store
      'MARKET_B', # market
    ],
    'COMPRAS': [
      'MERCADOLIVRE',
      'GAMES',
      '00000000000353', # Steam
    ],
    'VIAGEMS': ['TRAVEL_A', 'HOTEL_A', 'HOTEL'],
    'OUTROS': ['PERSON_B']
  }], 
}

CATEGORIES_WITH_KEYWORDS.each do |category_key, subcategory_mappings|
  category = Category.find_or_initialize_by(name: category_key)
  category.save!

  subcategory_mappings.first.each do |subcategory_name, keywords|
    subcategory = Subcategory.find_or_initialize_by(name: subcategory_name, category: category)
    subcategory.save!

    keywords.each do |keyword_name|
      k = Keyword.find_or_initialize_by(name: keyword_name, subcategory: subcategory)
      k.save!
    end
  end
rescue ActiveRecord::RecordInvalid => e
  puts "Skipping duplicate record: #{e.record.inspect}"
end

