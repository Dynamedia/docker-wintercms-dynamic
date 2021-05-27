PHP and Nginx

This will install Winter CMS inside the container. There is no persistence.

You should probably not be using this.

Set the environment variables in docker-compose.yml and docker-compose up

The image will do the following:

- Clone Winter CMS repository
- Checkout any specified commit hash
- Apply pull request if specified
- Require development version of Storm if requested

If a PR is needed for Storm, that will be applied and storm will be re-required as a local package

- Install plugins as specified.


This is an early test version and might not work properly yet.