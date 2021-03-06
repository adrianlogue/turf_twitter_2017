# this takes the previous data from the startup file
# now we look at retweet h-index

data_orderby_retweets <- data_timelines_working[with(data_timelines_working, order(screen_name, -retweet_count)), ]

# I will get the same results if I remove all tweets with no retweets
# this will save processing time
data_orderby_retweets <- subset(data_orderby_retweets, retweet_count > 0)

# I expect that I can slice this up by screen_name, then output to a new file of screen_name + h-index
data_orderby_retweet_hindex <- data.frame()


# refactor the screen names and number them for easy subsetting
data_orderby_retweets$screen_name_factored <- factor(data_orderby_retweets$screen_name)
data_orderby_retweets$user_integer <- as.numeric(data_orderby_retweets$screen_name_factored)

j <- max(data_orderby_retweets$user_integer)

for (i in 1:j) {
  # this gets us a single user to work with
  working_user <- subset(data_orderby_retweets, user_integer == i)
  
  user <- as.character(working_user[1, "screen_name"])
  
  # now we will calculate the retweet h-index for working_user
  rts <- working_user[, 13]
  
  h_index_retweets <- h_index(rts)
  
  if(length(h_index_retweets) == 0 | !is.numeric(h_index_retweets) | is.infinite(h_index_retweets)){
    h_index_retweets <- 0
  }
  
  # now for that user we should have a h_index_retweets
  # I'd like to now write that
  newline <- cbind.data.frame(user, h_index_retweets)
  data_orderby_retweet_hindex <- rbind.data.frame(data_orderby_retweet_hindex, newline)
}
# beep(sound = 3)

data_orderby_retweet_hindex$user <- reorder(data_orderby_retweet_hindex$user, data_orderby_retweet_hindex$h_index_retweets)

# order this, then select top 25
order_rt <- data_orderby_retweet_hindex[with(data_orderby_retweet_hindex, order(-h_index_retweets)), ]

forPlot <- data.frame(h_index_retweets=order_rt$h_index_retweets, user=order_rt$user)

forPlot <- forPlot %>%
  group_by(user) %>%
  top_n(n = 1, wt = h_index_retweets)

forPlot <- unique(forPlot)

forPlot <- forPlot[1:50, ]

p <- ggplot(data = forPlot, aes(x = h_index_retweets, y = user))  
p + theme_cowplot(font_family = "Avenir Next") +
  background_grid(major = "xy") +
  geom_point(shape = 0) +
  labs(x = "h-index (based on retweets",
       y = "Twitter Username",
       caption = "h-index: number of tweets (n) with at least (n) retweets\ne.g. an h-index of 50 means that account had 50 tweets\nthat were retweeted 50 or more times (higher is better)",
       title = paste("50 Accounts With Most Shared Content in", subject_title),
       subtitle = "Compiled by Adrian Logue (@AdrianLogue)"
  )

