# Cache
Solution to [task](https://github.com/eqlabs/recruitment-exercises/tree/master/cache),
providing simple self-rehydrating cache for 0-arity functions.

## Remarks
1. I decided to extract implementation of `Cache` into `Cache.Server`. I did not want to change provided API, but it didn't accept genserver pid's as parameters. While it is common to do it for global genservers, it makes testing painful, as you have to deal with global state. Instead, I created an application module to start a named instance, which is called by Cache module.
2. Both `Cache.Server` and `Cache.Store` have their own tests, reasonably comprehensively checking the desired functionality.
3. Since I guessed the inteded usecase is global instance, I made sure main genserver loop is not locking. Function calculation happens in other process and I use `Process.send_after/3`to handle waiting for timeouts and alike.
4. I tried to use descriptive variable and function names, but possibly you have higher standards of documentation. In team setting I adjust to agreed standards, but for a task I find it a bit pointless.

