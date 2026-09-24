-- =============================================================================
-- Brewly · Datos semilla: catálogo de métodos de preparación del sistema
-- =============================================================================

insert into public.brew_methods (owner_id, slug, name, category, icon, description, default_params)
values
  (null, 'espresso',     'Espresso',      'espresso',  'cup.and.saucer.fill',
   'Extracción a presión (~9 bar).',
   '{"dose_g":18,"yield_g":36,"temp_c":93,"time_s":28}'),
  (null, 'v60',          'Hario V60',     'pour_over', 'drop.fill',
   'Filtrado cónico de flujo rápido.',
   '{"dose_g":15,"water_g":250,"temp_c":94,"time_s":180}'),
  (null, 'chemex',       'Chemex',        'pour_over', 'drop.fill',
   'Filtrado con papel grueso, taza limpia.',
   '{"dose_g":30,"water_g":500,"temp_c":94,"time_s":270}'),
  (null, 'kalita-wave',  'Kalita Wave',   'pour_over', 'drop.fill',
   'Filtrado de fondo plano, extracción uniforme.',
   '{"dose_g":15,"water_g":250,"temp_c":93,"time_s":195}'),
  (null, 'origami',      'Origami',       'pour_over', 'drop.fill',
   'Dripper versátil compatible con filtros cónicos y planos.',
   '{"dose_g":15,"water_g":240,"temp_c":94,"time_s":165}'),
  (null, 'aeropress',    'AeroPress',     'pressure',  'arrow.down.circle.fill',
   'Inmersión con presión manual.',
   '{"dose_g":15,"water_g":230,"temp_c":85,"time_s":120}'),
  (null, 'french-press', 'Prensa francesa','immersion','mug.fill',
   'Inmersión total con filtro metálico.',
   '{"dose_g":30,"water_g":500,"temp_c":95,"time_s":240}'),
  (null, 'clever',       'Clever Dripper','immersion', 'mug.fill',
   'Inmersión con liberación por válvula.',
   '{"dose_g":18,"water_g":300,"temp_c":94,"time_s":180}'),
  (null, 'moka',         'Moka',          'pressure',  'flame.fill',
   'Cafetera italiana de estufa.',
   '{"dose_g":16,"water_g":160,"time_s":300}'),
  (null, 'siphon',       'Sifón',         'siphon',    'flask.fill',
   'Inmersión al vacío.',
   '{"dose_g":20,"water_g":300,"temp_c":92,"time_s":150}'),
  (null, 'cold-brew',    'Cold Brew',     'cold_brew', 'snowflake',
   'Inmersión en frío de larga duración.',
   '{"dose_g":100,"water_g":1000,"temp_c":4,"time_s":64800}'),
  (null, 'other',        'Otro',          'other',     'questionmark.circle',
   'Método no listado.',
   '{}')
on conflict do nothing;
