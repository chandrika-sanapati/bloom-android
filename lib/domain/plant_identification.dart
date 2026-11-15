class PlantCandidate {
  const PlantCandidate({
    required this.scientificName,
    required this.commonNames,
    required this.score,
    this.gbifId,
    this.powoId,
  });

  final String scientificName;
  final List<String> commonNames;
  final double score;
  final String? gbifId;
  final String? powoId;

  String get displayName =>
      commonNames.isEmpty ? scientificName : commonNames.first;
}

class PlantIdentificationResult {
  const PlantIdentificationResult({
    required this.candidates,
    this.providerVersion,
    this.remainingRequests,
  });

  final List<PlantCandidate> candidates;
  final String? providerVersion;
  final int? remainingRequests;
}
