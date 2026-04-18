# ============================================================
# PRÉDICTIONS TETRIS — Code complet
# BUT Science des Données · Promo 2026 · Équipe 5
# ============================================================
# ÉTAPE 0 : téléchargez d'abord le fichier tetris_ucacorp.csv
# depuis le chat et placez-le dans votre dossier Projet_data
# ============================================================

library(dplyr)

# ============================================================
# ÉTAPE 1 — CHARGEMENT DES DONNÉES
# ============================================================

# Charger le CSV déjà préparé (plus simple que le JSON)
df <- read.csv(
  "C:/Users/jodab/OneDrive/Documents/Projet Intense/Projet_data/tetris_ucacorp.csv",
  stringsAsFactors = FALSE
)

# Vérification
cat("Parties chargées :", nrow(df), "\n")
cat("Variables :", paste(names(df), collapse = ", "), "\n\n")
head(df)

# Nettoyer : garder seulement les parties jouées
df <- df %>% filter(nb_tours > 1)
cat("Après nettoyage :", nrow(df), "parties\n\n")

# Variable cible binaire : bonne partie = score >= médiane
seuil    <- median(df$score_final)
df$bonne <- as.integer(df$score_final >= seuil)
cat("Seuil bonne partie :", seuil, "pts |",
    sum(df$bonne), "bonnes /", sum(df$bonne == 0), "mauvaises\n\n")


# ============================================================
# ÉTAPE 2 — EXPLORATION RAPIDE
# ============================================================

# Distribution du score final
summary(df$score_final)

# Graphique de distribution
hist(
  df$score_final,
  main   = "Distribution des scores finaux",
  xlab   = "Score final",
  col    = "#1565C0",
  border = "white",
  breaks = 15
)
abline(v = seuil, col = "red", lwd = 2, lty = 2)
legend("topright", legend = paste("Médiane :", seuil),
       col = "red", lty = 2, lwd = 2)


# ============================================================
# PRÉDICTION 1 — RÉGRESSION LINÉAIRE SIMPLE
# Question : peut-on prédire le score depuis le nb de tours
#            et le niveau max atteint ?
# ============================================================

cat("\n===== PRÉDICTION 1 : Régression linéaire simple =====\n")

modele_lm <- lm(score_final ~ nb_tours + level_max + full_lines,
                data = df)
summary(modele_lm)

# Ajouter les prédictions au dataframe
df$pred_lm <- predict(modele_lm, df)

# Graphique valeurs réelles vs prédites — même style que votre exemple
plot(
  df$score_final,
  df$pred_lm,
  main = "Régression linéaire — Valeurs réelles vs prédictions",
  xlab = "Score réel",
  ylab = "Score prédit",
  pch  = 19,
  col  = "blue"
)
abline(a = 0, b = 1, col = "red", lwd = 2)
grid()

cat("R² =", round(summary(modele_lm)$r.squared, 3), "\n")


# ============================================================
# PRÉDICTION 2 — RÉGRESSION LINÉAIRE AVEC COMPORTEMENT
# Question : les actions du joueur améliorent-elles la prédiction ?
# ============================================================

cat("\n===== PRÉDICTION 2 : Régression avec comportement =====\n")

modele_comp <- lm(
  score_final ~ nb_tours + level_max + full_lines +
                rot_par_tour + drop_par_tour + nb_none,
  data = df
)
summary(modele_comp)

df$pred_comp <- predict(modele_comp, df)

plot(
  df$score_final,
  df$pred_comp,
  main = "Régression comportement — Valeurs réelles vs prédictions",
  xlab = "Score réel",
  ylab = "Score prédit",
  pch  = 19,
  col  = "purple"
)
abline(a = 0, b = 1, col = "red", lwd = 2)
grid()

cat("R² =", round(summary(modele_comp)$r.squared, 3), "\n")


# ============================================================
# PRÉDICTION 3 — RÉGRESSION LOGISTIQUE
# Question : peut-on prédire si une partie sera bonne ou mauvaise ?
# (c'est le même modèle que votre équipe utilise avec res_glm)
# ============================================================

cat("\n===== PRÉDICTION 3 : Régression logistique =====\n")

modele_glm <- glm(
  bonne ~ nb_tours + level_max + rot_par_tour + drop_par_tour,
  data   = df,
  family = binomial
)
summary(modele_glm)

# Probabilités prédites (entre 0 et 1)
df$prob_bonne <- modele_glm$fitted.values

# Graphique — même style que votre exemple
plot(
  df$score_final,
  df$prob_bonne,
  main = "Régression logistique — Score réel vs Probabilité de bonne partie",
  xlab = "Score réel",
  ylab = "Probabilité prédite (bonne partie)",
  pch  = 19,
  col  = "blue"
)
abline(h = 0.5, col = "red", lwd = 2, lty = 2)
legend("bottomright", legend = "Seuil décision 0.5",
       col = "red", lty = 2, lwd = 2)
grid()

# Taux de bonne classification
df$pred_classe <- as.integer(df$prob_bonne >= 0.5)
taux_glm       <- mean(df$pred_classe == df$bonne)
cat("Précision logistique :", round(taux_glm * 100, 1), "%\n")


# ============================================================
# PRÉDICTION 4 — ARBRE DE DÉCISION
# Question : quelles règles simples expliquent les bonnes parties ?
# ============================================================

cat("\n===== PRÉDICTION 4 : Arbre de décision =====\n")

# Installer si nécessaire (à faire une seule fois)
# install.packages("rpart")
# install.packages("rpart.plot")
library(rpart)
library(rpart.plot)

arbre <- rpart(
  bonne ~ nb_tours + level_max + full_lines +
          rot_par_tour + drop_par_tour + nb_none,
  data   = df,
  method = "class"
)

# Visualiser l'arbre — très lisible
rpart.plot(
  arbre,
  main          = "Arbre de décision — Règles pour une bonne partie",
  type          = 4,
  extra         = 104,
  fallen.leaves = TRUE,
  cex           = 0.85
)

# Précision de l'arbre
df$pred_arbre <- as.integer(predict(arbre, df, type = "class")) - 1
taux_arbre    <- mean(df$pred_arbre == df$bonne)
cat("Précision arbre :", round(taux_arbre * 100, 1), "%\n")


# ============================================================
# ÉTAPE FINALE — COMPARAISON DES MODÈLES
# ============================================================

rmse <- function(reel, predit) round(sqrt(mean((reel - predit)^2)), 1)

cat("\n========== COMPARAISON DES MODÈLES ==========\n")
cat(sprintf("%-35s R² = %.3f  |  RMSE = %s\n",
    "Régression simple (tours+level+lignes)",
    summary(modele_lm)$r.squared,
    rmse(df$score_final, df$pred_lm)))
cat(sprintf("%-35s R² = %.3f  |  RMSE = %s\n",
    "Régression + comportement",
    summary(modele_comp)$r.squared,
    rmse(df$score_final, df$pred_comp)))
cat(sprintf("%-35s Précision = %.1f%%\n",
    "Régression logistique",
    taux_glm * 100))
cat(sprintf("%-35s Précision = %.1f%%\n",
    "Arbre de décision",
    taux_arbre * 100))
cat("==============================================\n")
