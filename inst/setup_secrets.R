

setup_secrets <- function(repo, owner) {
  message("• Setting up GitHub Actions secrets...")
  public_key <- gh::gh("/repos/{owner}/{repo}/actions/secrets/public-key", repo = repo, owner = owner)
  tkey <- tempfile()
  sys::exec_wait("git-crypt", c("export-key", tkey), std_out = FALSE, std_err = FALSE)
  GIT_CRYPT_KEY64 <- base64enc::base64encode(tkey)
  file.remove(tkey)
  secret <- base64enc::base64encode(sodium::simple_encrypt(charToRaw(GIT_CRYPT_KEY64), base64enc::base64decode(public_key$key)))
  gh::gh("/repos/{owner}/{repo}/actions/secrets/{secret_name}", owner = owner, repo = repo, secret_name = "GIT_CRYPT_KEY",
         .method = "PUT", encrypted_value = secret, key_id = public_key$key_id)
  message("  • GIT_CRYPT_KEY set as repository secret.")

}

setup_secrets("wahisdb", "ecohealthalliance")
