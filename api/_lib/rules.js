// Le regole di prodotto di Sobremesa, lato server: da qui in poi è QUESTA
// la fonte di verità (l'engine Swift resta per gli stati di presentazione).
// Stessi numeri di ProductRules.swift — se cambiano, cambiano in entrambi.
export const RULES = {
  maxFriends: 12,
  maxCircles: 5,
  emberDimAfterDays: 2,
  emberWarningAfterDays: 4,
  emberExpulsionAfterDays: 7,
  emberMinimumMembers: 2,
  pointsPost: 2,
  pointsComment: 1,
  pointsRetake: 1,
  pointsSilencePenalty: -2,
  pointsExpulsionPenalty: -5,
  scoreMin: 0,
  scoreMax: 100,
  initialScore: 50,
};

export function clampScore(v) {
  return Math.min(RULES.scoreMax, Math.max(RULES.scoreMin, v));
}

export function daysOfSilence(lastActivity, now = new Date()) {
  return Math.max(0, Math.floor((now - new Date(lastActivity)) / 86_400_000));
}
