/**
 * Calculate player rating based on statistics (0-10 scale)
 * @param {Object} stats - User statistics object
 * @param {number} stats.posts - Number of posts
 * @param {number} stats.followers - Number of followers
 * @param {number} stats.following - Number of following
 * @param {number} stats.totalReactions - Total reactions (likes + loves + talents + amazing)
 * @param {number} stats.comments - Total comments
 * @param {number} stats.shares - Total shares
 * @param {number} stats.views - Total views
 * @returns {number} Rating from 0.0 to 10.0
 */
function calculateRating(stats) {
    const {
        posts = 0,
        followers = 0,
        following = 0,
        totalReactions = 0,
        comments = 0,
        shares = 0,
        views = 0
    } = stats;

    let rating = 0;

    // 1. Content Score (0-2.5 points) - Based on post count
    if (posts === 0) {
        rating += 0;
    } else if (posts <= 5) {
        rating += 0.5;
    } else if (posts <= 20) {
        rating += 1.0;
    } else if (posts <= 50) {
        rating += 1.5;
    } else if (posts <= 100) {
        rating += 2.0;
    } else {
        rating += 2.5;
    }

    // 2. Audience Score (0-2.5 points) - Based on followers
    if (followers === 0) {
        rating += 0;
    } else if (followers <= 10) {
        rating += 0.5;
    } else if (followers <= 50) {
        rating += 1.0;
    } else if (followers <= 100) {
        rating += 1.5;
    } else if (followers <= 500) {
        rating += 2.0;
    } else {
        rating += 2.5;
    }

    // 3. Engagement Score (0-3.0 points) - Based on reactions per post
    if (posts > 0) {
        const avgReactionsPerPost = totalReactions / posts;
        
        if (avgReactionsPerPost <= 5) {
            rating += 0.5;
        } else if (avgReactionsPerPost <= 20) {
            rating += 1.0;
        } else if (avgReactionsPerPost <= 50) {
            rating += 1.5;
        } else if (avgReactionsPerPost <= 100) {
            rating += 2.0;
        } else if (avgReactionsPerPost <= 200) {
            rating += 2.5;
        } else {
            rating += 3.0;
        }
    }

    // 4. Interaction Score (0-1.0 points) - Based on comments and shares
    if (posts > 0) {
        const interactionPerPost = (comments + shares) / posts;
        const interactionScore = Math.min(1.0, interactionPerPost * 0.1);
        rating += interactionScore;
    }

    // 5. Reach Score (0-1.0 points) - Based on total views
    if (views === 0) {
        rating += 0;
    } else if (views <= 100) {
        rating += 0.2;
    } else if (views <= 500) {
        rating += 0.4;
    } else if (views <= 1000) {
        rating += 0.6;
    } else if (views <= 5000) {
        rating += 0.8;
    } else {
        rating += 1.0;
    }

    // Ensure rating is between 0 and 10
    rating = Math.min(10, Math.max(0, rating));
    
    // Round to 1 decimal place
    rating = Math.round(rating * 10) / 10;

    return rating;
}

module.exports = { calculateRating };
