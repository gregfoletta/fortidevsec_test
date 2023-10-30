library(httr)
library(jsonlite)
library(stringr)
library(glue)


fgt_api_get <- function(uri, path, token, ssl_verify = FALSE) {
    ssl_verify_int = as.integer(ssl_verify)
    
    uri_path_token <- glue("{uri}/api/v2/{path}?access_token={token}")
    
    GET(
        url = uri_path_token,
        config = config(
            ssl_verifypeer = ssl_verify_int,
            ssl_verifyhost = ssl_verify_int
        )
    )
}

fgt_api_caller <- function(uri, token, ssl_verify = FALSE, post = function(x) {x} ) {
    function(path, local_post = function(x) {x} ) {
        fgt_api_get(uri = uri, token = token, path = path, ssl_verify = ssl_verify) |> 
            content() |>
            local_post() |> 
            post()
    }
}
