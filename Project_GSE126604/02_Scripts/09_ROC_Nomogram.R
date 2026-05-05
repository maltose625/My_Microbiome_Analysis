# ==========================================
# 临床诊断效能评估与列线图构建
# ==========================================

# 清除环境
rm(list = ls())
options(stringsAsFactors = FALSE)

# 安装核心包
# if(!require("pROC")) install.packages("pROC")
# if(!require("rms")) install.packages("rms")
# if(!require("brglm2")) install.packages("brglm2")  # 用于处理分离问题

library(pROC)
library(rms)
library(ggplot2)
library(brglm2)

cat("🚀 启动临床模型构建流程...\n")

# 1. 数据准备
hub_genes <- c("COX6B1", "NDUFS8", "NDUFA5", "COX7C", "UQCRFS1", "NDUFB9")
model_data <- as.data.frame(t(clean_expr_matrix[hub_genes, ]))
model_data$Risk <- as.factor(y)  # 确保是因子

# 标准化基因表达（强烈推荐）
model_data[, hub_genes] <- lapply(model_data[, hub_genes], as.numeric)  # 强制转数值
model_data[, hub_genes] <- scale(model_data[, hub_genes])               # 标准化

cat("建模数据准备完毕，维度：", nrow(model_data), "x", ncol(model_data), "\n")
print(head(model_data, 3))
table(model_data$Risk)  # 检查平衡性

# 2. 构建 Logistic 回归（优先尝试 bias-reduction）
cat("\n📈 正在拟合 Logistic 回归...\n")

# 先尝试普通 glm，失败则用 brglm
logit_model <- tryCatch({
  glm(Risk ~ ., data = model_data, family = binomial(link = "logit"),
      control = glm.control(maxit = 100))
}, error = function(e) NULL)

if (is.null(logit_model) || !logit_model$converged) {
  cat("⚠️  普通 glm 未收敛，使用 brglm bias-reduction 方法...\n")
  logit_model <- brglm(Risk ~ ., data = model_data, family = binomial(link = "logit"))
}

summary(logit_model)

# 3. ROC 曲线
cat("\n📊 正在绘制 ROC 曲线...\n")
pred_prob <- predict(logit_model, type = "response")
roc_obj <- roc(model_data$Risk, pred_prob, quiet = TRUE)

cat("🏆 联合诊断模型 AUC = ", round(auc(roc_obj), 3), "\n")

pdf("D:/A/WSL_Microbiome_Project/Project_GSE126604/03_Results/07_ROC_Curve/07_ROC_Curve_6Genes.pdf", width = 7, height = 7)
plot(roc_obj, print.auc = TRUE, auc.polygon = TRUE, grid = TRUE,
     max.auc.polygon = TRUE, print.thres = TRUE,
     main = "ROC Curve of 6-Gene Diagnostic Panel")
dev.off()

# 4. Nomogram（使用 rms）
cat("\n🎯 正在生成列线图 (Nomogram)...\n")
dd <- datadist(model_data)
options(datadist = "dd")

# 使用 lrm 构建（推荐）
f <- lrm(Risk ~ COX6B1 + NDUFS8 + NDUFA5 + COX7C + UQCRFS1 + NDUFB9, 
         data = model_data, x = TRUE, y = TRUE)

nom <- nomogram(f, fun = plogis, 
                funlabel = "Risk Probability of HCC",
                lp = FALSE)

pdf("D:/A/WSL_Microbiome_Project/Project_GSE126604/03_Results/07_ROC_Curve/08_Nomogram_6Genes.pdf", width = 11, height = 7)
plot(nom, xfrac = 0.35)
dev.off()

# 5. 推荐额外：校准曲线（重要！）
pdf("D:/A/WSL_Microbiome_Project/Project_GSE126604/03_Results/07_ROC_Curve/09_Calibration.pdf", width = 6, height = 6)
plot(calibrate(f, method = "boot", B = 200), main = "Calibration Curve")
dev.off()

cat("✅ 所有图表已保存！\n")


# ====================== 1. 模型定义与比较 ======================
# ====================== 模型比较（可靠版本） ======================
library(lmtest)   # 用于 Likelihood Ratio Test

# 确保两个模型
f_6 <- f                                      # 6基因模型
f_5 <- lrm(Risk ~ COX6B1 + NDUFS8 + NDUFA5 + UQCRFS1 + NDUFB9, 
           data = model_data, x = TRUE, y = TRUE)

cat("=== 模型比较 ===\n")
cat("6-Gene Model AIC :", round(AIC(f_6), 3), "\n")
cat("5-Gene Model AIC :", round(AIC(f_5), 3), "\n")
cat("AIC 差异         :", round(AIC(f_5) - AIC(f_6), 3), "\n\n")

# 方法1：使用 lmtest 包的 lrtest（最稳定）
cat("Likelihood Ratio Test (lrtest):\n")
lr_test <- lrtest(f_6, f_5)
print(lr_test)

# ====================== 2. 选择最终模型 ======================
# 推荐使用 5 基因模型（更简洁，COX7C 边缘显著）
f_final <- f_5

cat("✅ 已选定 5-Gene Model 作为最终模型\n")

# ====================== 3. 生成最终 Nomogram ======================
dd <- datadist(model_data)
options(datadist = "dd")

nom_final <- nomogram(f_final, 
                      fun = plogis,
                      funlabel = "Risk Probability of HCC",
                      lp = FALSE)

pdf("D:/A/WSL_Microbiome_Project/Project_GSE126604/03_Results/07_ROC_Curve/08_Nomogram_5Genes_Final.pdf", width = 11, height = 7)
plot(nom_final, xfrac = 0.35)
dev.off()

# ====================== 4. 生成最终 DCA ======================
model_data$pred_prob_final <- predict(f_final, type = "fitted")

library(dcurves)

pdf("D:/A/WSL_Microbiome_Project/Project_GSE126604/03_Results/07_ROC_Curve/10_DCA_5Genes_Final.pdf", width = 8, height = 6)
dca_final <- dca(Risk ~ pred_prob_final, 
                 data = model_data,
                 thresholds = seq(0, 0.8, by = 0.01),
                 label = list(pred_prob_final = "5-Gene Model"))

plot(dca_final, 
     main = "Decision Curve Analysis\n5-Gene Diagnostic Model",
     smooth = TRUE)
dev.off()

cat("✅ 最终 5-Gene 模型的 Nomogram 和 DCA 已生成！\n")


