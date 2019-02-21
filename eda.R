library(ggplot2)
library(dplyr)
library(magrittr)
library(JJHmisc)
library(JJHmisc)
library(dplyr)
library(tidyr)
library(reshape2)
library(ggrepel)
library(lfe)

GetPrice <- function(x) as.numeric(gsub(",", "", gsub("\\$","",x)))

df <- read.csv("stockX.csv", stringsAsFactors = FALSE) %>%
    mutate(
        Order.Date = as.Date(Order.Date, format = "%m/%d/%Y"),
        Release.Date = as.Date(Release.Date, format = "%m/%d/%Y"),
        Sale.Price = GetPrice(Sale.Price),
        Retail.Price = GetPrice(Retail.Price),
        Brand = gsub(" ", "", Brand)
    ) %>%
    mutate(Sneaker.Name = factor(Sneaker.Name))

ggplot(data = df, aes(x = Retail.Price, y = Sale.Price)) + geom_point()

df.by.day.by.sneaker <- df %>% group_by(Order.Date, Sneaker.Name, Brand) %>%
    summarise(num.orders = n(),
              sale.price = mean(Sale.Price),
              retail.price = mean(Retail.Price),
              release.date = Release.Date[1]
              )

g <- ggplot(data = df.by.day.by.sneaker, aes(x = Order.Date, y = sale.price)) +
    facet_wrap(~Sneaker.Name, ncol = 5) + 
    geom_line() +
    scale_y_log10() +
    geom_line(aes(y = retail.price), colour = "red", linetype = "dashed") +
    geom_vline(aes(xintercept = release.date), colour = "black", linetype = "dotted") +
    theme_bw()

JJHmisc::writeImage(g, "time_series", width = 12, height = 12, path = "./")


## Illustrates the Halloween
ggplot(data = df.by.day.by.sneaker, aes(x = Order.Date, y = num.orders)) +
    facet_wrap(~Sneaker.Name, ncol = 5) + 
    geom_line() +
    scale_y_log10() +
    geom_vline(aes(xintercept = release.date), colour = "black", linetype = "dotted") +
    geom_vline(xintercept = as.Date("2017-10-30"), colour = "orange") +
    geom_vline(xintercept = as.Date("2018-10-30"), colour = "orange") +
    geom_vline(xintercept = as.Date("2019-10-30"), colour = "orange")

## Halloween zoom in 
df.tmp <- df.by.day.by.sneaker %>%
    filter(Order.Date > release.date) %>%
    filter(release.date < (as.Date("2018-10-30") - 30)) %>% 
    filter(Order.Date > (as.Date("2018-10-30") - 10)) %>%
    filter(Order.Date < (as.Date("2018-10-30") + 10)) 

g <- ggplot(data = df.tmp, aes(x = Order.Date, y = num.orders)) +
    facet_wrap(~Sneaker.Name, ncol = 5) + 
    geom_line() +
    geom_vline(xintercept = as.Date("2018-10-30"), colour = "orange") 

standard.rate <- 0.095

df.tmp.2 <- df.tmp %>%
    group_by(Sneaker.Name) %>% 
    mutate(day.before.orders = num.orders[Order.Date == as.Date("2018-10-30")][1]) %>%
    mutate(avg.before.orders = mean(num.orders[Order.Date < as.Date("2018-10-31")])) %>% 
    filter(day.before.orders > 2) %>%
    mutate(num.orders.normalized = num.orders / day.before.orders) %>%
    group_by(Sneaker.Name) %>%
    mutate(avg.price = mean(sale.price)) %>%
    ungroup %>%
    group_by(Sneaker.Name) %>% 
    mutate(seller.fee = ifelse(Order.Date == as.Date("2018-10-31"), max(c(5, 0.031 * avg.price)),
                           max(c(5, standard.rate * avg.price))))

df.melt <- df.tmp.2 %>% select(Order.Date, Brand, Sneaker.Name, sale.price, num.orders.normalized, seller.fee) %>%
    melt(id.vars = c("Sneaker.Name", "Order.Date", "Brand"))

pretty.variable <- list(
    "seller.fee" = "Estimated seller fee (USD)",
    "sale.price" = "Average sale price (USD)",
    "num.orders.normalized" = "Num. orders (normalized to 1 on Oct 30, 2018)"
)

df.melt$variable <- with(df.melt, as.character(pretty.variable[as.character(variable)]))


df.label <- df.melt[1, ] %>%
    mutate(Order.Date = as.Date("2018-10-31"),
           value = 1000, 
           label = "Boo!")



df.sneaker.label <- df.melt %>%
    filter(variable == "Num. orders (normalized to 1 on Oct 30, 2018)") %>%
    filter(Order.Date == as.Date("2018-10-31"))

g <- ggplot(data = df.melt, aes(x = Order.Date, y = value, group = Sneaker.Name, colour = Brand)) +
    geom_line() +
    theme_bw() +
    facet_wrap(~variable, ncol = 1, scale = "free_y") + 
    geom_vline(xintercept = as.Date("2018-10-31"), colour = "orange", linetype = "dashed") +
    ylab("") +
    xlab("Order Date") +
    geom_text(data = df.label, aes(label = "Boo!"), colour = "orange") +
    geom_label_repel(data = df.sneaker.label %>% filter(as.character(Brand) == "Yeezy"),
                     aes(label = Sneaker.Name),
                     xlim = c(as.Date("2018-11-03"), NA),
                     segment.color = "grey",
                     size = 2, 
                     force = 10,
                     ylim = c(2, NA)
                     ) +
    geom_label_repel(data = df.sneaker.label %>% filter(as.character(Brand) == "Off-White"),
                     aes(label = Sneaker.Name),
                     size = 2,
                     xlim = c(NA, as.Date("2018-10-28")),
                     segment.color = "grey",
                     force = 10,
                     ylim = c(2, NA)
                     ) +
    theme(legend.position = "none")

print(g)

JJHmisc::writeImage(g, "volume", width = 8, height = 7, path = "./")

# Regression elasticity 

m <- felm(log(num.orders) ~ log(seller.fee) | Sneaker.Name | 0 | Sneaker.Name, data = df.tmp.2)

df.tmp.2 %<>% mutate(Halloween = as.Date("2018-10-31") == Order.Date)

m <- felm(log(num.orders) ~ Halloween | Sneaker.Name | 0 | Sneaker.Name, data = df.tmp.2)


