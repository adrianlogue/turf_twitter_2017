# R Twitter Analysis for Golf (or any subject really)
library(rtweet)

# NOTE: First time you execute a rtweet function you'll see a browser window pop up and you
#       need to authorise the rtweet application to access your twitter.
#       There is alternatively a token based method of authentication that requires a 
#       twitter app to be setup, but I've chosen not to do it that way.
#       Note also you might need to install the httpuv package to allow R to interact
#       with a browser on your machine


# This function retrieves and de-dups follower lists and/or friend lists for multiple accounts
get_unique_twitter_accounts <- function(accounts, sample_size, operation_mode=1){
  # Possible operation modes:
  # 1 - get followers
  # 2 - get friends
  # 3 - get followers and friends
  all_accounts <- data.frame()
  
  # NOTE: This could probably be done without a loop
  for (account in accounts) {
    temp_accounts <- data.frame()
    
    # retrieve followers from twitter
    if(operation_mode == 1){
      temp_accounts <- get_followers(account, n = sample_size, retryonratelimit = TRUE)
    }else if(operation_mode == 2){
      temp_accounts <- get_friends(account, n = sample_size, retryonratelimit = TRUE)
    }else{ # assume mode 3
      temp_accounts <- get_followers(account, n = sample_size, retryonratelimit = TRUE)
      temp_accounts2 <- get_friends(account, n = sample_size, retryonratelimit = TRUE)
      # drop the "user" column from the friends data frame
      temp_accounts2$user <- NULL
      temp_accounts <- rbind(temp_accounts, temp_accounts2)
    }

    # accumulate them into one list
    all_accounts <- rbind(all_accounts, temp_accounts)
  }
  
  # de-dup and return
  return(unique(all_accounts))
}

# Get the accounts of interest

# I've toyed with a few different ideas here. picking these accounts is the toughest part of this excercise
candidate_accounts <- get_unique_twitter_accounts(accounts_of_interest, max_sample_size, 1)
print(paste("Found", nrow(candidate_accounts), "candidate accounts"))

# Get the narrower accounts of interest
narrower_candidate_accounts <- get_unique_twitter_accounts(narrower_accounts_of_interest, max_sample_size, 1)
print(paste("Found", nrow(narrower_candidate_accounts), "narrower candidate accounts"))

# Now find only the accounts that intersect both lists
data_accounts <- merge(candidate_accounts, narrower_candidate_accounts, by="user_id")
print(paste("Found", nrow(data_accounts), "target accounts"))
data_accounts$user_id <- as.character(data_accounts$user_id)


# Get more detailed info for the target accounts
data_accounts <- lookup_users(data_accounts$user_id)

# this removes the private accounts, also the least active ones
data_accounts <- subset(data_accounts, protected == FALSE & statuses_count >= min_status_updates)
print(paste("Found", nrow(data_accounts), "target accounts after removing protected and inactive"))

# this attempts to remove those that seem to have automated follow/follower system
# in order to get a large audience (i.e. bots)
data_accounts <- subset(data_accounts, friends_count < max_friend_count)
print(paste("Found", nrow(data_accounts), "target accounts after removing potential bots"))

# Remove some specific accounts you want to remove by name
data_accounts$screen_name_tolower <- tolower(data_accounts$screen_name)
data_accounts <- data_accounts[!data_accounts$screen_name_tolower %in% accounts_to_exclude, ]

# now we're going to load the tweets for the target accounts
data_timelines <- data.frame()

# TODO: A better R programmer than me would probably be able to remove this loop
for (i in 1:nrow(data_accounts)) {
  # As this takes a long time and runs unattended, I don't want to return to the screen to find
  # it has died on an error. I'll live with the errors, I just want to continue on, hence the tryCatch
  tryCatch({
    # To manage twitter rate limiting I'm going to check every 10 iterations to see where we're at
    # NOTE: rtweet.get_timeline includes a parameter to manage rate limiting, but I find it just doesn't always work
    #       so I'm explicitly turning it off in the call to get_timeline
    if((i %% 10) == 0){
      rate_limit <- rate_limit("get_timeline")
      # to give a bit of buffer I'm testing to see if my limit is approaching 0, but not quite at 0. 80 seems safe
      if(rate_limit$remaining < 80){
        # use the returned data to work out how long to sleep, also adding another 10secs to be safe
        seconds_to_sleep <- as.integer(as.numeric(rate_limit$reset) * 60) + 10
        print(paste("Approaching rate limit, resting for ", seconds_to_sleep, "secs"))
        Sys.sleep(seconds_to_sleep)
      }
    }
  
    # Get the tweets for this account
    temp_timeline <- get_timeline(as.character(data_accounts[i, 3]), n = max_tweet_count, check = F)
  
    # Filter on start & end dates
    temp_timeline <- subset(temp_timeline, created_at >= start_date & created_at <= end_date)
  
    # Add this person's tweets to the complete list
    data_timelines <- rbind(data_timelines, temp_timeline)
  
    # Show progress
    print(paste("Completed", i, "of", nrow(data_accounts), "accounts"))
  }, error=function(e){cat("ERROR :",conditionMessage(e), "\n")})
  
}

# Now we want to thin out the data a little further
# Remove all the retweets
# data_timelines <- subset(data_timelines, is_retweet == FALSE)

# Re-apply the minimum tweet count (previously we did it to the accounts list, now the timeline)
# data_timelines$tweet_count <- ave(data_timelines$is_retweet, data_timelines$screen_name, FUN = length)
# data_timelines <- data_timelines[with(data_timelines, tweet_count >= 50), ]

# beep me when it's done
# beep(sound = 3)