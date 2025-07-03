CATEGORIES_WITH_KEYWORDS = {
  # category => [{subcategories => [keywords]}, subcategories => [keywords]...]
  earnings: [{
    'SALARIO': ['SALARIO', 'LIBERACAO_CAMBIO', 'LIBERACAO_CAMBIO_BANCO_LIQUIDACAO_CONTR'],
    'TRANSFERENCIAS': ['TRANSFERENCIA_DA_POUPANCA'],
    'OUTROS': ['DISTRIBUICAO', 'RECEBIMENTO'],
  }],
  investments: [{
    'POUPANCA': ['APLICACAO'],
    'TRANSFERENCIA': ['PAGAMENTO_PIX_05748903199'],
  }],
  confort: [{
    'FOOD': [
      'IFOOD',
      'IFD',
      'PLANET_PIZZA',
      'ACAI_ITALIA',
      'THEBURGAN',
      'JESSICA_FERNANDES',
      'PANIFICADORA',
      'MC_DONALDS',
      'SUKIYA',
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
    'BEM_ESTAR': ['DROGAMED'],
    'LUNNA': [
      '87133946149_PATRICIA_PEREIRA', # ESCOLA LUNNA
      'BRINQUEDOS',
      'PAPELARIA',
    ],
    'CASA': [
      'PAGAMENTO_PIX_24860100000156', # MANUTENÇÃO AR CONDICIONADO
    ],
  }],
  fixed_expenses: [{
    'CONTAS': [
      'CAMILLA',
      'UNIMED',
      'CELG',
      'SEG_VIDA',
      'RODRIGUES_R_C_LTDA', 'RODRIGUES_RODRIGUES', # CONTADOR
      'CLIENT_CO_SERVICOS', # Internet
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
      'TOKIO_MARINE',
      'SIDNEY_ALVES' # LAVAGEM
    ],
    'MERCADO': ['DANIEL_SUPERMERCADO', 'SUPERMERCADO_RAYANNE', 'MERCADODPAULA', 'SUPERMERCADO_FAMILIA'],
    'BEM_ESTAR': [
      'SKYFIT',
      'PÉRICLES_RODRIGUES',
      'SACOLAO',
      'HORTIFRUTI',
      'SESIPARC', 'SESI_DR_GO', '03786187000199',
      'VILMA_SANTANA' # corte cabelo lunna
    ],
    'ASSINATURA': ['GPT']
  }],
  pleasure: [{
    'ALCOOL': [
      'DISTRIBUIDORA',
      'BEBIDA',
      'TABACARIA',
      'BAR',
      'JULIETA_GASTROBAR',
      'XICO_BARU',
      'RESTAURAN',
      'HOPSLAND',
      'SUPERMERCADO_ANDRADE', # mercado perto da 10
      'EMPORIO_BUENO', # Distribuidora de bebidas perto a chacara colorado,
      'PAULO_ENRIQUE_DUARTE', # Distribuidora de bebidas perto do militar
      'BONTELO_SUPERMERCADO', # Mercado na final da avenida colorado
    ],
    'COMPRAS': [
      'MERCADOLIVRE',
      'GAMES',
      '51583189000123', # Steam
    ],
    'VIAGEMS': ['SALTO_CORUMBA', 'NIKKEY_PALACE', 'HOTEL'],
    'OUTROS': ['MATHEUS_DUTRA']
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

