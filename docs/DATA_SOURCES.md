# Offline data and scientific conventions

Snapshot retrieved 25 October 2026. No runtime network requests are required.

## Elements

`assets/datasets/elements.json`: [Bowserinator/Periodic-Table-JSON](https://github.com/Bowserinator/Periodic-Table-JSON), CC BY-SA 3.0. The original license is bundled as `ELEMENTS_LICENSE.md`. This is a secondary compiled dataset, not an independent verification against IUPAC/NIST for every measurement. Its source fields and radius definitions remain in the JSON. The application excludes the source's hypothetical element 119. Halogens are categorized by group 17 through astatine; uncertain superheavy classifications remain as supplied.

Temperatures are K, ionization energies/electron affinities kJ/mol, empirical radii pm, and normalized densities g/cm³. Unknown values remain null. Electron affinity can be signed. Atomic radius definitions are not interchangeable. Superheavy-element masses often represent isotope mass numbers rather than standard atomic weights; the dataset currently does not provide a uniform estimated/experimental flag, which is a release limitation.

## Isotopes, ionic radii, oxidation states

`supplement.json`: exported from [Mendeleev](https://github.com/lmmentel/mendeleev)'s `mendeleev/elements.db`, MIT, copyright Lukasz Mentel. See bundled `MENDELEEV_LICENSE.txt` and [data definitions and primary bibliography](https://mendeleev.readthedocs.io/en/stable/data.html).

Contains 3,557 isotope records, 507 ionic-radius records and 601 oxidation-state records. Abundances are percentages. Half-lives retain their original units and unavailable values. Mass uncertainties, abundance uncertainties and half-life uncertainties remain in the bundled data. Element details use oxidation states categorized `main`. Ionic heatmaps specify oxidation charge and sixfold coordination (VI); where spin is specified, high-spin rows are used. They do not mix different ionic charges into an unlabeled trend.

## Molecules

Nineteen conformers are from [PubChem PUG REST](https://pubchem.ncbi.nlm.nih.gov/docs/pug-rest), using `compound/cid/{CID}/record/JSON?record_type=3d`. A PubChem conformer is a modeled geometry, not necessarily an experimental gas/liquid-state structure. Coordinates are Å. Molecule IDs preserve PubChem CIDs and source links. Explicit hydrogens and bond orders are retained. Benzene uses Kekulé connectivity.

Hydrogen's 3D endpoint returned no record. Its two atoms are placed at ±0.3707 Å, using the 0.7414 Å equilibrium bond length from [NIST CCCBDB](https://cccbdb.nist.gov/exp2x.asp?casno=1333740&charge=0). This exception is labeled in its source field.

Hydrogen-bond donor/acceptor counts and IUPAC names are recorded PubChem properties (CACTVS conventions), available for untouched presets. Editing coordinates/connectivity clears those recorded properties, avoiding stale scientific claims. No electrostatic partial charges or normal-mode frequencies are invented. PubChem source records can contain third-party contributions; consult [PubChem data usage policies](https://pubchem.ncbi.nlm.nih.gov/docs/data-usage-policies) before commercial redistribution.

## Calculation limits

- Molecular formulas use Hill ordering, explicit atoms only; formal charge is shown separately.
- Molar masses sum bundled atomic masses; no isotope-specific molecular editing is implemented.
- Lengths, angles, dihedrals and local shape labels derive from actual coordinates. Shape matching is geometric, not electronic-structure determination.
- Typical-valence checks are heuristic warnings. They do not prove chemical stability, radical multiplicity, aromaticity, stereochemistry or protonation.
- Bond relaxation minimizes Σ(r − r₀)², with covalent-radius sums and bond-order scaling. The residual is in Å², not energy. It is deliberately **not** described as UFF/MMFF or a validated geometry optimization.
- Vibration displacements are illustrative. No calculated cm⁻¹ frequencies are shown.
- Atom shells and the probability cloud are educational schematics; the cloud is 1s-like and not a many-electron solution for the selected element.

`dataset-manifest.json` records hashes of the distributed JSON snapshots.
