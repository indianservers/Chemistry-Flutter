import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/chemistry.dart';
import 'molecule_library.dart';

class MoleculeImportDialog extends StatefulWidget {
  final ChemistryData data;
  final ValueChanged<Molecule> onImport;
  const MoleculeImportDialog({
    super.key,
    required this.data,
    required this.onImport,
  });
  @override
  State<MoleculeImportDialog> createState() => _ImportState();
}

class _ImportState extends State<MoleculeImportDialog> {
  final input = TextEditingController();
  Molecule? preview;
  String? error;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void parse() {
    try {
      final value = jsonDecode(input.text);
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object');
      }
      if (value['version'] != null && value['version'] != 1) {
        throw const FormatException('Unsupported format version');
      }
      final m = Molecule.fromJson(value);
      setState(() {
        preview = m;
        error = null;
      });
    } catch (e) {
      setState(() => error = 'Invalid molecule: $e');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      preview == null ? 'Import molecular JSON' : 'Review imported structure',
    ),
    content: SizedBox(
      width: 500,
      child: SingleChildScrollView(
        child: preview == null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Paste a Chemistry Universe JSON export. Graph, coordinates and formal charges will be checked before import.',
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: input,
                    maxLines: 10,
                    decoration: InputDecoration(
                      hintText: 'Versioned molecular JSON',
                      errorText: error,
                      errorMaxLines: 4,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Transform.scale(
                      scale: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(30),
                        child: MoleculeThumbnail(molecule: preview!),
                      ),
                    ),
                  ),
                  Text(preview!.name, style: const TextStyle(fontSize: 21)),
                  Text(
                    '${widget.data.formula(preview!)} · ${preview!.atoms.length} atoms · ${preview!.bonds.length} bonds',
                  ),
                  Text(
                    '${widget.data.mass(preview!).toStringAsFixed(2)} g/mol',
                  ),
                  Text(
                    'Net formal charge: ${preview!.atoms.fold(0, (v, a) => v + a.charge)}',
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Structural checks passed. Typical-valence checks are warnings, not a proof of stability.',
                  ),
                  for (final warning in validate(preview!))
                    Text(
                      warning,
                      style: const TextStyle(color: Colors.amber, fontSize: 11),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    'Recorded source: ${preview!.source}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      if (preview != null)
        TextButton(
          onPressed: () => setState(() => preview = null),
          child: const Text('Edit JSON'),
        ),
      FilledButton(
        onPressed: preview == null
            ? parse
            : () {
                widget.onImport(preview!);
                Navigator.pop(context);
              },
        child: Text(preview == null ? 'Preview structure' : 'Import structure'),
      ),
    ],
  );
}
