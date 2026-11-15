import 'soil_care.dart';

enum SoilCheck { nutrients, mix, roots }

enum SoilAnswer { yes, no, unsure }

class SoilQuestion {
  const SoilQuestion(this.text, this.help);
  final String text;
  final String help;
}

class SoilAdvice {
  const SoilAdvice(this.title, this.reason, {this.actions = const {}});
  final String title;
  final String reason;
  final Set<SoilCareAction> actions;
}

/// Version 1: advisory inspection branches, not a diagnosis or calendar feed plan.
class SoilAssessment {
  static const version = 1;
  static String label(SoilCheck check) => switch (check) {
    SoilCheck.nutrients => 'Adding nutrients',
    SoilCheck.mix => 'Refresh potting mix',
    SoilCheck.roots => 'Repotting',
  };
  static List<SoilQuestion> questions(SoilCheck check) => switch (check) {
    SoilCheck.nutrients => const [
      SoilQuestion(
        'Is the plant actively growing?',
        'Look for new leaves or shoots. The time of year alone does not tell us.',
      ),
      SoilQuestion(
        'Is fertilizer still supplying nutrients?',
        'Check the label for a recent feed or fresh mix containing fertilizer. Choose Not sure if you cannot tell.',
      ),
      SoilQuestion(
        'Have watering, light, and drainage been checked?',
        'These conditions can also affect growth. A placement confirmation alone does not measure light.',
      ),
    ],
    SoilCheck.mix => const [
      SoilQuestion(
        'Can excess water escape from the pot?',
        'Check the inner pot and collected water in its saucer or cover pot. Do not add water to an already-wet plant as a test.',
      ),
      SoilQuestion(
        'Is the mix compacted or difficult to wet evenly?',
        'Consider an ongoing change in the mix, not just its age or one watering.',
      ),
      SoilQuestion(
        'Are roots tightly crowded with little mix left?',
        'Only answer Yes if you have observed this. You do not need to unpot the plant to finish this check.',
      ),
    ],
    SoilCheck.roots => const [
      SoilQuestion(
        'Can excess water escape from the pot?',
        'Standing water or blocked drainage may need attention first. Do not add water just to test drainage.',
      ),
      SoilQuestion(
        'Are roots tightly crowded with little mix left?',
        'Dense circling roots are more useful evidence than plant height or a single root at a drainage hole.',
      ),
      SoilQuestion(
        'Does the mix have ongoing wetting or drying problems?',
        'A change in the mix can need a different response from giving roots more space.',
      ),
    ],
  };
  static bool needsMoreAnswers(SoilCheck check, List<SoilAnswer> answers) {
    if (answers.isEmpty) return true;
    if (answers.first != SoilAnswer.yes) return false;
    if (check == SoilCheck.nutrients &&
        answers.length >= 2 &&
        answers[1] != SoilAnswer.no) {
      return false;
    }
    return answers.length < 3;
  }

  static SoilAdvice advise(SoilCheck check, List<SoilAnswer> answers) {
    if (answers.isEmpty) {
      return const SoilAdvice(
        'Inspect this first',
        'There is not enough information to suggest a soil-care action.',
      );
    }
    final a = answers[0];
    final b = answers.length > 1 ? answers[1] : SoilAnswer.unsure;
    final c = answers.length > 2 ? answers[2] : SoilAnswer.unsure;
    if (check == SoilCheck.nutrients) {
      if (a == SoilAnswer.no) {
        return const SoilAdvice(
          'No action suggested now',
          'Without active growth, adding nutrients is not the first step. Review growing conditions if you are concerned.',
        );
      }
      if (a == SoilAnswer.unsure) {
        return const SoilAdvice(
          'Inspect this first',
          'Look for active growth before deciding whether to feed. Leaf colour alone cannot establish a nutrient deficiency.',
        );
      }
      if (b != SoilAnswer.no) {
        return const SoilAdvice(
          'Check the product or mix label first',
          'Nutrients may already be available from a feed or fresh mix. Follow the product instructions before adding more; unknown history is not proof that feeding is needed.',
        );
      }
      if (c != SoilAnswer.yes) {
        return const SoilAdvice(
          'Review growing conditions first',
          'Check watering, actual light, and drainage before adding nutrients for unexplained poor growth.',
        );
      }
      return const SoilAdvice(
        'Adding nutrients may help',
        'An actively growing plant may benefit from nutrients when no feed is currently being supplied. Use a suitable houseplant product and follow its label for timing and dilution. This does not confirm a deficiency.',
        actions: {SoilCareAction.nutrientsAdded},
      );
    }
    if (a != SoilAnswer.yes) {
      return const SoilAdvice(
        'Check drainage first',
        'Review drainage holes and water collected around the inner pot. A simple correction may be enough; this does not automatically call for repotting or fresh mix. Do not water an already-wet plant to test it.',
      );
    }
    final crowded = check == SoilCheck.roots ? b : c;
    final mixProblem = check == SoilCheck.roots ? c : b;
    if (crowded == SoilAnswer.yes) {
      return SoilAdvice(
        'Repotting may help',
        'The root crowding you observed may warrant repotting. Choose a suitable pot with drainage; a much larger pot can hold excess moisture. Fresh mix may be part of the job, but record only the actions you actually perform.',
        actions: {
          SoilCareAction.repotted,
          if (mixProblem == SoilAnswer.yes) SoilCareAction.mixRefreshed,
        },
      );
    }
    if (mixProblem == SoilAnswer.yes) {
      return const SoilAdvice(
        'Refreshing the mix may help',
        'Ongoing mix problems may warrant suitable fresh potting mix. This does not necessarily require a bigger pot. If problems persist, root space and watering conditions may also need review.',
        actions: {SoilCareAction.mixRefreshed},
      );
    }
    if (crowded == SoilAnswer.unsure || mixProblem == SoilAnswer.unsure) {
      return const SoilAdvice(
        'Inspect this first',
        'There is not enough evidence to suggest repotting or replacing mix. Review the mix and root space when you can do so safely; no immediate action is required by this check.',
      );
    }
    return const SoilAdvice(
      'No action suggested now',
      'Your answers do not suggest a mix refresh or repotting at present. You can revisit this check if conditions change.',
    );
  }
}
