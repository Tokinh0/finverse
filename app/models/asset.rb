class Asset < ApplicationRecord
  ASSET_TYPES = {
    'renda_variavel' => 'Renda Variável',
    'renda_fixa' => 'Renda Fixa',
    'renda_fixa_internacional' => 'Renda Fixa Internacional',
    'criptomoedas' => 'Criptomoedas',
    'reits' => 'REITs',
    'fundos_imobiliarios' => 'Fundos Imobiliários',
    'acoes_internacionais' => 'Ações Internacionais',
    'acoes_nacionais' => 'Ações Nacionais',
    'reserva' => 'Reserva',
  }.freeze

  enum asset_type: ASSET_TYPES
end
