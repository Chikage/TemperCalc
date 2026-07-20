final class TemperamentFamilySeed {
  const TemperamentFamilySeed(this.name, this.comma);

  final String name;
  final String comma;
}

/// Raw temperament family seeds, in the same order as the upstream catalog.
const List<TemperamentFamilySeed> temperamentFamilySeeds =
    <TemperamentFamilySeed>[
      // Rank 2.
      TemperamentFamilySeed('diaschismic', '2147483648/2109289329'),
      TemperamentFamilySeed('flattone', '137781/131072'),
      TemperamentFamilySeed('flattone', '729/704'),
      TemperamentFamilySeed('gariboh', '3125/3087'),
      TemperamentFamilySeed('garischismic', '[25 -14 0 -1]'),
      TemperamentFamilySeed('hedgehog', '118098/117649'),
      TemperamentFamilySeed('injera', '6561/6272'),
      TemperamentFamilySeed('joan', '14641/14336'),
      TemperamentFamilySeed('leapday', '[31 -21 1]'),
      TemperamentFamilySeed('liese', '[-9 11 0 -3]'),
      TemperamentFamilySeed('machine', '352/343'),
      TemperamentFamilySeed('meantone', '59049/57344'),
      TemperamentFamilySeed('mohajira', '214358881/204800000'),
      TemperamentFamilySeed('mothra', '[-36 0 1 12]'),
      TemperamentFamilySeed('nexus', '1771561/1769472'),
      TemperamentFamilySeed('octacot', '5764801/5668704'),
      TemperamentFamilySeed('orgone', '65536/65219'),
      TemperamentFamilySeed('orwell', '839808/823543'),
      TemperamentFamilySeed('pajara', '2197265625/1977326743'),
      TemperamentFamilySeed('passion', '[18 -4 -5]'),
      TemperamentFamilySeed('porcupine', '1331/1296'),
      TemperamentFamilySeed('rastmic', '243/242'),
      TemperamentFamilySeed('rodan', '[20 -17 3]'),
      TemperamentFamilySeed('sensamagic', '245/243'),
      TemperamentFamilySeed('sensi', '1647086/1594323'),
      TemperamentFamilySeed('superpyth', '20480/19683'),
      TemperamentFamilySeed('supra', '8192/8019'),
      TemperamentFamilySeed('superflat', '1053/1024'),
      TemperamentFamilySeed('vulture', '[24 -21 4]'),

      // Rank 3.
      TemperamentFamilySeed('akea', '2200/2187'),
      TemperamentFamilySeed('apollo', '100/99'),
      TemperamentFamilySeed('arcturus', '15625/15309'),
      TemperamentFamilySeed('jove', '2401/2400'),
      TemperamentFamilySeed('buzurg', '169/168'),
      TemperamentFamilySeed('canopus', '16875/16807'),
      TemperamentFamilySeed('counterpyth', '1216/1215'),
      TemperamentFamilySeed('demeter', '686/675'),
      TemperamentFamilySeed('freya', '[-21 -13 6 0 8]'),
      TemperamentFamilySeed('guanyin', '1728/1715'),
      TemperamentFamilySeed('island', '676/675'),
      TemperamentFamilySeed('konbini', '56/55'),
      TemperamentFamilySeed('landscape', '250047/250000'),
      TemperamentFamilySeed('marvel', '225/224'),
      TemperamentFamilySeed('marveltwin', '325/324'),
      TemperamentFamilySeed('metric', '703125/702464'),
      TemperamentFamilySeed('minerva', '5632/5625'),
      TemperamentFamilySeed('mint', '36/35'),
      TemperamentFamilySeed('mothwellsmic', '99/98'),
      TemperamentFamilySeed('odin', '[-17 24 -18 0 6]'),
      TemperamentFamilySeed('olympic', '131072/130977'),
      TemperamentFamilySeed('parapyth', '352/351'),
      TemperamentFamilySeed('pele', '5120/5103'),
      TemperamentFamilySeed('pentacircle', '896/891'),
      TemperamentFamilySeed('pine', '4000/3993'),
      TemperamentFamilySeed('portent', '166375/165888'),
      TemperamentFamilySeed('ragismic', '4375/4374'),
      TemperamentFamilySeed('starling', '126/125'),
      TemperamentFamilySeed('superkleismic', '1953125/1889568'),
      TemperamentFamilySeed('supermagic', '875/864'),
      TemperamentFamilySeed('symbiotic', '19712/19683'),
      TemperamentFamilySeed('thor', '1890625/1889568'),
      TemperamentFamilySeed('trimitone', '8019/8000'),
      TemperamentFamilySeed('vulkan', '512/495'),
      TemperamentFamilySeed('zeus', '121/120'),
      TemperamentFamilySeed('zeus', '176/175'),
      TemperamentFamilySeed('zeus', '6144/6125'),

      // Rank 4.
      TemperamentFamilySeed('animist', '105/104'),
      TemperamentFamilySeed('biome', '91/90'),
      TemperamentFamilySeed('huntmic', '640/637'),
      TemperamentFamilySeed('kalismic', '9801/9800'),
      TemperamentFamilySeed('keenanismic', '385/384'),
      TemperamentFamilySeed('lehmerismic', '3025/3024'),
      TemperamentFamilySeed('mynucumic', '196/195'),
      TemperamentFamilySeed('ratwolf', '351/350'),
      TemperamentFamilySeed('swetismic', '540/539'),
      TemperamentFamilySeed('werckismic', '441/440'),

      // Rank 1 and equivalence continua.
      TemperamentFamilySeed('blackwood', '256/243'),
      TemperamentFamilySeed('gothic', '[27 -17]'),
      TemperamentFamilySeed('mystery', '[46 -29]'),
      TemperamentFamilySeed('countercomp', '[65 -41]'),
      TemperamentFamilySeed('mercator', '[-84 53]'),
      TemperamentFamilySeed('compton', '531441/524288'),
      TemperamentFamilySeed('19-comma', '[-30 19]'),
      TemperamentFamilySeed('whitewood', '2187/2048'),
      TemperamentFamilySeed('augmented', '128/125'),
      TemperamentFamilySeed('birds', '[72 0 -31]'),
      TemperamentFamilySeed('cloudy', '[-14 0 0 5]'),
      TemperamentFamilySeed('birds', '[-87 0 0 31]'),
      TemperamentFamilySeed('bug', '27/25'),
      TemperamentFamilySeed('father', '16/15'),
      TemperamentFamilySeed('mavila', '135/128'),
      TemperamentFamilySeed('dicot', '25/24'),
      TemperamentFamilySeed('porcupine', '250/243'),
      TemperamentFamilySeed('tetracot', '20000/19683'),
      TemperamentFamilySeed('artoneutral', '32000000000/31381059609'),
      TemperamentFamilySeed('amity', '1600000/1594323'),
      TemperamentFamilySeed('undetrita', '205891132094649/204800000000000'),
      TemperamentFamilySeed('gravity', '129140163/128000000'),
      TemperamentFamilySeed('absurdity', '10460353203/10240000000'),
      TemperamentFamilySeed('meantone', '81/80'),
      TemperamentFamilySeed('python', '43046721/41943040'),
      TemperamentFamilySeed('gracecordial', '[-34 20 1]'),
      TemperamentFamilySeed('schismatic', '32805/32768'),
      TemperamentFamilySeed('undim', '[41 -20 -4]'),
      TemperamentFamilySeed('misty', '67108864/66430125'),
      TemperamentFamilySeed('diaschismic', '2048/2025'),
      TemperamentFamilySeed('diminished', '648/625'),
      TemperamentFamilySeed('negri', '16875/16384'),
      TemperamentFamilySeed('magic', '3125/3072'),
      TemperamentFamilySeed('kleismic', '15625/15552'),
      TemperamentFamilySeed('enneadecal', '[-14 -19 19]'),
      TemperamentFamilySeed('parakleismic', '[8 14 -13]'),
      TemperamentFamilySeed('sensi', '78732/78125'),
      TemperamentFamilySeed('unicorn', '1594323/1562500'),
      TemperamentFamilySeed('nusecond', '[5 13 -11]'),
      TemperamentFamilySeed('myna', '[9 9 -10]'),
      TemperamentFamilySeed('valentine', '[13 5 -9]'),
      TemperamentFamilySeed('würschmidt', '[17 1 -8]'),
      TemperamentFamilySeed('hemithirds', '[38 -2 -15]'),
      TemperamentFamilySeed('tertiaseptal', '[-59 5 22]'),
      TemperamentFamilySeed('orwell', '[-21 3 7]'),
      TemperamentFamilySeed('miracle', '[-25 7 6]'),
      TemperamentFamilySeed('tritonic', '[-29 11 5]'),
      TemperamentFamilySeed('sentinel', '[-33 15 4]'),
      TemperamentFamilySeed('ennealimmal', '[1 -27 18]'),
      TemperamentFamilySeed('chlorine', '[-52 -17 34]'),
      TemperamentFamilySeed('vishnu', '[23 6 -14]'),
      TemperamentFamilySeed('rainy', '2100875/2097152'),
      TemperamentFamilySeed('miracle', '823543/819200'),
      TemperamentFamilySeed('didacus', '3136/3125'),
      TemperamentFamilySeed('jubilismic', '50/49'),
      TemperamentFamilySeed('trienstonian', '28/27'),
      TemperamentFamilySeed('semaphore', '49/48'),
      TemperamentFamilySeed('slendric', '1029/1024'),
      TemperamentFamilySeed('septiness', '67108864/66706983'),
      TemperamentFamilySeed('buzzard', '65536/64827'),
      TemperamentFamilySeed('archytas', '64/63'),
      TemperamentFamilySeed('ennealimmal', '[-11 -9 0 9]'),
      TemperamentFamilySeed('enneadecal', '[-37 57 0 -19]'),
    ];

final Map<String, List<TemperamentFamilySeed>> _familiesByName =
    _buildFamiliesByName();

final Map<String, TemperamentFamilySeed> _familiesByComma =
    Map<String, TemperamentFamilySeed>.unmodifiable(
      <String, TemperamentFamilySeed>{
        for (final TemperamentFamilySeed seed in temperamentFamilySeeds)
          seed.comma: seed,
      },
    );

/// Returns every seed with the exact, case-sensitive [name].
List<TemperamentFamilySeed> temperamentFamiliesNamed(String name) =>
    _familiesByName[name] ?? const <TemperamentFamilySeed>[];

/// Returns the seed with the exact [comma], or `null` when it is unknown.
TemperamentFamilySeed? temperamentFamilyForComma(String comma) =>
    _familiesByComma[comma];

Map<String, List<TemperamentFamilySeed>> _buildFamiliesByName() {
  final Map<String, List<TemperamentFamilySeed>> mutableIndex =
      <String, List<TemperamentFamilySeed>>{};

  for (final TemperamentFamilySeed seed in temperamentFamilySeeds) {
    (mutableIndex[seed.name] ??= <TemperamentFamilySeed>[]).add(seed);
  }

  return Map<String, List<TemperamentFamilySeed>>.unmodifiable(
    mutableIndex.map(
      (String name, List<TemperamentFamilySeed> seeds) =>
          MapEntry<String, List<TemperamentFamilySeed>>(
            name,
            List<TemperamentFamilySeed>.unmodifiable(seeds),
          ),
    ),
  );
}
