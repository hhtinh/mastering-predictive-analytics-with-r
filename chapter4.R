####################################################
# Gradient Descent
####################################################

x = seq(0,20,by=0.01)
y = exp(-x/10)*sin(x)
library(ggplot2)
p <- qplot(x,y)
p <- p + ggtitle("Example of a Non-Convex Function") 
p <- p + theme(plot.title = element_text(lineheight=.8, face="bold", vjust=2))
p <- p + xlab("Weight w")  
p <- p + ylab("Cost Function J(w)") 
p 

####################################################
# Perceptron 
####################################################

# Dummy Data:
set.seed(4910341)
x1 = runif(200, 0, 10)
set.seed(2125151)
x2 = runif(200, 0, 10)
x = cbind(x1,x2)
y = sign(-0.89 + 2.07*x[,1] - 3.09*x[,2])

# Algorithm
step_function <- function(x) {
   if (x < 0) -1 else 1
}

pocket_perceptron <- function(x, y, learning_rate, max_iterations) {
  nObs = nrow(x)
  nFeatures = ncol(x)
  w = rnorm(nFeatures+1,0,2) # Random weight initialization
  current_iteration = 0
  has_converged = F
  best_weights = w
  best_error = nObs #Start by assuming you get all the examples wrong
  while ((has_converged == F) & (current_iteration < max_iterations)) {
    has_converged = T # Assume we are done unless we misclassify an observation
    current_error = 0 # Keep track of misclassified observations
    for (i in 1:nObs) {
      xi = c(1,x[i,]) # Append 1 for the dummy input feature x0
      yi = y[i]
      y_predicted = step_function(sum(w*xi))
      if (yi != y_predicted) {
        current_error = current_error + 1
        has_converged = F # We have at least one misclassified example
        w = w + learning_rate*sign(yi-y_predicted)*xi
      }
    }
    if (current_error < best_error) {
      best_error = current_error
      best_weights = w
    }
    current_iteration = current_iteration+1
  }
  model <- list("weights" = best_weights, "converged" = has_converged, "iterations" = current_iteration)
  model
}

pmodel = pocket_perceptron(x,y,0.1,1000)

# Plot
a_pop = -0.89/3.09
b_pop = 2.07/3.09
a_model = -pmodel$weights[1]/pmodel$weights[3]
b_model = -pmodel$weights[2]/pmodel$weights[3]

p <- ggplot(data = NULL, aes(x=x1, y=x2, shape = ifelse(y > 0, "Class 1","Class -1")))
p <- p + geom_point()
p <- p + ggtitle("Binary Classification with the Perceptron Algorithm")
p <- p + theme(plot.title = element_text(lineheight=.8, face="bold", vjust=2), legend.position="bottom")
p <- p + xlab("x1")  
p <- p + ylab("x2") 
p <- p + scale_shape_manual(name="Class Labels", values=c(1,15))
p <- p + geom_abline(intercept = a_pop, slope = b_pop, aes(linetype="Population Line"), size = 0.5, show_guide=T)
p <- p + geom_abline(intercept = a_model, slope = b_model, aes(linetype="Model Line"), size = 0.5, show_guide=T)
p <- p + scale_linetype_manual(name = "Decision Boundaries", values = c("dashed","solid"))
p <- p + guides(shape = guide_legend(override.aes = list(linetype = 0 )), 
       linetype = guide_legend())
p

####################################################
# Energy Efficiency
####################################################

library(xlsx)
eneff <- read.xlsx2("ENB2012_data.xlsx",sheetIndex = 1, colClasses=rep("numeric",10))
names(eneff) <- c("relCompactness", "surfArea", "wallArea", "roofArea", "height", "orientation", "glazArea", "glazAreaDist", "heatLoad", "coolLoad")
eneff <- eneff[complete.cases(eneff),]

library(caret)
eneff$orientation <- factor(eneff$orientation)
eneff$glazAreaDist <- factor(eneff$glazAreaDist)
dummies <- dummyVars(heatLoad + coolLoad ~ ., data = eneff)
eneff_data <- cbind(as.data.frame(predict(dummies, newdata = eneff)),eneff[,9:10])

set.seed(474576)
eneff_sampling_vector <- createDataPartition(eneff_data$heatLoad, p = 0.80, list = FALSE)
eneff_train <- eneff_data[eneff_sampling_vector,1:16]
eneff_train_outputs <- eneff_data[eneff_sampling_vector,17:18]
eneff_test <- eneff_data[-eneff_sampling_vector,1:16]
eneff_test_outputs <- eneff_data[-eneff_sampling_vector,17:18]

# Pre Process Inputs
eneff_pp <- preProcess(eneff_train, method = c("range"))
eneff_train_pp <- predict(eneff_pp, eneff_train)
eneff_test_pp <- predict(eneff_pp, eneff_test)

# Pre Process Outputs
eneff_train_out_pp <- preProcess(eneff_train_outputs, method = c("range"))
eneff_train_outputs_pp <- predict(eneff_train_out_pp,eneff_train_outputs)
eneff_test_outputs_pp <- predict(eneff_train_out_pp,eneff_test_outputs)

library("neuralnet")
n <- names(eneff_data)
f <- as.formula(paste("heatLoad + coolLoad ~", paste(n[!n %in% c("heatLoad","coolLoad")], collapse = " + ")))
eneff_model = neuralnet(f,data=cbind(eneff_train_pp,eneff_train_outputs_pp),hidden=10)

eneff_model <- neuralnet(f, 
 data=cbind(eneff_train_pp,eneff_train_outputs_pp),hidden=10, act.fct="logistic",linear.output=TRUE, err.fct="sse", rep=1)

####################################################
# Evaluating multilayer perceptrons for regression
####################################################

test_predictions <- compute(eneff_model,eneff_test_pp)

reverse_range_scale <- function(v, ranges) {
  return( (ranges[2] - ranges[1])*v + ranges[1] )
}

test_predictions <- as.data.frame(test_predictions$net.result)
output_ranges <- eneff_train_out_pp$ranges
test_predictions_unscaled <- sapply(1:2,function(x) reverse_range_scale(test_predictions[,x],output_ranges[,x]))

mse <- function(y_p, y) {
  return(mean((y-y_p)^2))
}

mse(test_predictions_unscaled[,1],eneff_test_outputs[,1])
mse(test_predictions_unscaled[,2],eneff_test_outputs[,2])
cor(test_predictions_unscaled[,1],eneff_test_outputs[,1])
cor(test_predictions_unscaled[,2],eneff_test_outputs[,2])

####################################################
# Glass with nnet
####################################################

glass <- read.csv("glass.data", header=FALSE)
names(glass) <- c("id","RI","Na", "Mg", "Al", "Si", "K", "Ca", "Ba", "Fe", "Type")
glass$id <- NULL

# Prepare outputs
glass$Type<- factor(glass$Type)
set.seed(4365677)
glass_sampling_vector <- createDataPartition(glass$Type, p = 0.80, list = FALSE)
glass_train <- glass[glass_sampling_vector,]
glass_test <- glass[-glass_sampling_vector,]

glass_pp <- preProcess(glass_train[1:9], method = c("range"))
glass_train <- cbind(predict(glass_pp, glass_train[1:9]),Type = glass_train$Type)
glass_test  <- cbind(predict(glass_pp, glass_test[1:9]), Type = glass_test$Type)

library("nnet")
glass_model <- nnet(Type ~ ., data = glass_train, size = 10)
glass_model <- nnet(Type ~ ., data = glass_train, size = 10, maxit = 1000)

train_predictions <- predict(glass_model, glass_train[,1:9], type = "class")
mean(train_predictions == glass_train$Type)

glass_model2 <- nnet(Type ~ ., data = glass_train, size = 50, maxit = 10000)
train_predictions2 <- predict(glass_model2, glass_train[,1:9], type = "class")
mean(train_predictions2 == glass_train$Type)

test_predictions2 <- predict(glass_model2, glass_test[,1:9], type = "class")
mean(test_predictions2 == glass_test$Type)

glass_model3 <- nnet(Type~., data = glass_train, size = 10, maxit = 10000, decay = 0.01)
train_predictions3 <- predict(glass_model3, glass_train[,1:9], type = "class")
mean(train_predictions3 == glass_train$Type)
test_predictions3 <- predict(glass_model3, glass_test[,1:9], type = "class")
mean(test_predictions3 == glass_test$Type)

library(caret)
nnet_grid <- expand.grid(.decay = c(0.1, 0.01, 0.001, 0.0001), .size = c(50, 100, 150, 200, 250))
nnetfit <- train(Type ~ ., data = glass_train, method = "nnet", maxit = 10000, tuneGrid = nnet_grid, trace = F, MaxNWts = 10000)

####################################################
# Load MNIST Database
####################################################

read_idx_image_data <- function(image_file_path) {
  con <- file(image_file_path, "rb")
  magic_number <- readBin(con, what = "integer", n=1, size=4, endian="big")
  n_images <- readBin(con, what = "integer", n=1, size=4, endian="big")
  n_rows <- readBin(con, what = "integer", n=1, size=4, endian="big")
  n_cols <- readBin(con, what = "integer", n=1, size=4, endian="big")
  n_pixels <- n_images * n_rows * n_cols
  pixels <- readBin(con, what = "integer", n=n_pixels, size=1, signed = F)
  image_data <- matrix(pixels, nrow = n_images, ncol= n_rows * n_cols, byrow=T)
  close(con)
  return(image_data)
}

read_idx_label_data <- function(label_file_path) {
  con <- file(label_file_path, "rb")
  magic_number <- readBin(con, what = "integer", n=1, size=4, endian="big")
  n_labels <- readBin(con, what = "integer", n=1, size=4, endian="big")
  label_data <- readBin(con, what = "integer", n=n_labels, size=1, signed = F)
  close(con)
  return(label_data)
}

mnist_train <- read_idx_image_data("mnist/train-images-idx3-ubyte")
mnist_train_labels <- read_idx_label_data("mnist/train-labels-idx1-ubyte")

display_digit <- function(image_vector, title = "") {
  reflected_image_matrix <- matrix(image_vector, nrow = 28, ncol = 28)
  image_matrix <- reflected_image_matrix[,28:1]
  gray_colors <- seq(from = 1, to = 0, by = -1/255)
  image(image_matrix, col = gray(gray_colors), xaxt='n', yaxt='n', main = title, bty="n")
}

num_images <- 7
par(mar=c(0,0,0,0)) 
layout(matrix(1:num_images, 1, num_images, byrow = TRUE))
sapply(1:num_images,function(x) display_digit(mnist_train[x,],mnist_train_labels[x]))

####################################################
# Process MNIST
####################################################

mnist_input <- mnist_train / 255
mnist_output <- as.factor(mnist_train_labels)

set.seed(252)
mnist_index <- sample(1:nrow(mnist_input),nrow(mnist_input))
mnist_data <- mnist_input[mnist_index,1:ncol(mnist_input)]
mnist_out_shuffled <- mnist_output[mnist_index] # Sort the output as well

library("RSNNS")
mnist_out <- decodeClassLabels(mnist_out_shuffled)
mnist_split <- splitForTrainingAndTest(mnist_data, mnist_out, ratio = 0.2)
mnist_norm <- normTrainingAndTestSet(mnist_split, type = "0_1")

start_time <- proc.time()
mnist_mlp <- mlp(mnist_norm$inputsTrain, mnist_norm$targetsTrain, size=100, inputsTest=mnist_norm$inputsTest, targetsTest=mnist_norm$targetsTest)
proc.time() - start_time

start_time <- proc.time()
mnist_mlp2 <- mlp(mnist_norm$inputsTrain, mnist_norm$targetsTrain, size=300, inputsTest=mnist_norm$inputsTest, targetsTest=mnist_norm$targetsTest)
proc.time() - start_time

mnist_class_test <- (0:9)[apply(mnist_norm$targetsTest,1,which.max)]
mlp_class_test <- (0:9)[apply(mnist_mlp$fittedTestValues,1,which.max)]
mlp2_class_test <- (0:9)[apply(mnist_mlp2$fittedTestValues,1,which.max)]

confusionMatrix(mnist_class_test, mlp2_class_test)

par(mar=c(2,4,2,2)) 
layout(matrix(1:2, 2, 1, byrow = TRUE))
plotIterativeError(mnist_mlp, main = "Iterative Error for 100 Neuron MLP Model")
legend("topright", c("Training Data", "Test Data"), col=c("black", "red"), lwd=c(1,1))
plotIterativeError(mnist_mlp2, main = "Iterative Error for 300 Neuron MLP Model")
legend("topright", c("Training Data", "Test Data"), col=c("black", "red"),lwd=c(1,1))

plotROC(mnist_mlp2$fittedTestValues[,2],mnist_norm$targetsTest[,2], main="ROC Curve for 300 Neuron MLP Model (Digit 1)", xlab="1 - Specificity", ylab = "Sensitivity")
abline(a = 0, b = 1, lty=2)
legend("bottomright", c("Model", "Random Classifier"), lty = c(1,2), lwd=c(1,1))
