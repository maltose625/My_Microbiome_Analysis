# ====================== 最终模型确认 ======================
# 确认最终模型为 5-Gene 模型（已剔除 COX7C）
print(f_final)

# ====================== 1. 提取系数并生成 Risk Score 公式 ======================
cat("=== 5-Gene Risk Score 公式 ===\n")

# 提取系数
coef_table <- coef(f_final)

# 生成 Risk Score 计算公式（仅使用模型中实际存在的变量）
predictors <- names(coef_table)[-1]  # 排除 Intercept

terms <- sapply(predictors, function(var) {
  coef_val <- round(coef_table[var], 4)
  paste0(coef_val, " * ", var)
})

intercept <- round(coef_table["(Intercept)"], 4)
risk_score_formula <- paste(c(terms, intercept), collapse = " + ")

cat("\nRisk Score 计算公式（Linear Predictor）：\n")
cat(risk_score_formula, "\n\n")

# 计算每个样本的 Risk Score 和概率
model_data$RiskScore <- predict(f_final, type = "lp")      # Linear Predictor
model_data$RiskProb  <- predict(f_final, type = "fitted")  # Probability (0-1)

cat("Risk Score 描述统计：\n")
print(summary(model_data$RiskScore))

# ====================== 2. Bootstrap 内部验证 ======================
library(rms)

# 确保模型已包含 x=TRUE, y=TRUE（如果之前没有，请重新拟合）
f_final <- lrm(Risk ~ COX6B1 + NDUFS8 + NDUFA5 + UQCRFS1 + NDUFB9, 
               data = model_data, x = TRUE, y = TRUE)

set.seed(2025)
cat("正在进行 Bootstrap 内部验证 (B = 500)...\n")

val_boot <- validate(f_final, method = "boot", B = 500)

print(val_boot)

# 提取校正后的 c-index (AUC)
dxy_corrected <- val_boot["Dxy", "index.corrected"]
c_index_corrected <- (dxy_corrected + 1) / 2

cat(sprintf("\nOptimism-corrected c-index (AUC): %.4f\n", c_index_corrected))

# ====================== 3. DCA 决策曲线分析 ======================
library(dcurves)

pdf("D:/A/WSL_Microbiome_Project/Project_GSE126604/03_Results/07_ROC_Curve/10_DCA_5Genes_Final.pdf", 
    width = 8, height = 6)

dca_final <- dca(Risk ~ pred_prob_final,
                 data = model_data,
                 thresholds = seq(0, 0.8, by = 0.01),
                 label = list(pred_prob_final = "5-Gene Model"))

plot(dca_final,
     main = "Decision Curve Analysis\n5-Gene Diagnostic Model",
     smooth = TRUE)

dev.off()

cat("✅ 最终 5-Gene 模型的 DCA 图已生成！\n")