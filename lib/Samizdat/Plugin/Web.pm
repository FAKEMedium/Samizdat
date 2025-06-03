package Samizdat::Plugin::Web;

use Mojo::Base 'Mojolicious::Plugin', -signatures;

use Samizdat::Model::Web;

sub register ($self, $app, $conf) {
  my $r = $app->routes;

  my $manager = $r->under($app->config->{managerurl})->under('web')->to(
    controller => 'Account',
    action     => 'authorize',
    level      => 'superadmin',
  );
  $manager->get('/')
    ->to(controller => 'Web', action => 'index', docpath => '/web/index.html')
    ->name('web_index');

  $r->get('/manifest.json')->to(controller => 'Web', action => 'manifest', docpath => 'manifest.json');
  $r->get('/robots.txt')->to(controller => 'Web', action => 'robots', docpath => 'robots.txt');
  $r->get('/humans.txt')->to(controller => 'Web', action => 'humans', docpath => 'humans.txt');
  $r->get('/ads.txt')->to(controller => 'Web', action => 'ads', docpath => 'ads.txt');
  $r->get('/.well-known/security.txt')->to(controller => 'Web', action => 'security', docpath => '.well-known/security.txt');
  $r->get('/')->to(controller => 'Web', action => 'getdoc', docpath => '');
  $r->get('/*docpath')->to(controller => 'Web', action => 'getdoc');

  $app->helper(web => sub ($self) {
    state $web = Samizdat::Model::Web->new(app => $app);
    return $web;
  });

  $app->helper(headlinebuttons => sub ($self, $chunkname =  'chunks/sharebuttons') {
    return ($chunkname) ? $self->app->include($chunkname) : '';
  });

}

1;

=encoding utf8

=head1 NAME

Samizdat::Plugin::Web - Mojolicious plugin for web-related functionality

=head1 DESCRIPTION

This plugin provides web-related functionality for the Samizdat application, including routes for manifest files,
robots.txt, humans.txt, ads.txt, security.txt, and a general document handler. The accompanying controller and model
handle the logic for rendering these documents and managing the web interface.

=head1 PARTS

=over

=item Samizdat::Plugin::Web

This is the main plugin module that registers the web routes and helpers.

=item Samizdat::Controller::Web

This controller handles the web-related actions, such as rendering the index page, serving static files, and managing
web documents.

=item Samizdat::Model::Web

This model provides the functionality to manage web documents, including fetching and rendering them based on the
requested path and language. Source markdown files are converted to HTML and returned in a data structure for assembly in the controller
and view.

=item Samizdat::Plugin::Utils

This module implements the after_render hook to inject some code, beautify HTML, and store optimized HTML files in the
static directory if the docpath stash is set.

=item samizdat.yml

Contains supported languages and the path to the source files.

=back


=head1 BUGS

Make controller/model/after render hook translate README.md to index.html and save it in the static cs, using a naming scheme containing
the language code, e.g. index.en.html, index.de.html, etc. The default language should be without a language code.

=head1 TODO

AI gave me a list of features to implement in the web plugin. Here is the list combined with my own ideas:

=over

=item Add database backend for web pages, so that they can be edited and managed through the admin interface.

=item Add caching for static files to improve performance.

=item Implement a more robust error handling mechanism for missing documents.

=item Add support for internationalization and localization of web pages.

=item Implement a search functionality for web pages.

=item Add support for custom themes and styles for web pages.

=item Implement a content management system (CMS) for easier management of web pages.

=item Add support for user-generated content and comments on web pages.

=item Implement a versioning system for web pages to track changes over time.

=item Add analytics and tracking for web page visits and user interactions.

=item Implement a sitemap generation feature for better SEO.

=item Add support for social media integration and sharing of web pages.

=item Implement a feedback mechanism for users to report issues or suggest improvements for web pages.

=item Add support for multimedia content (images, videos, etc.) on web pages.

=item Implement a responsive design for web pages to ensure compatibility with various devices.

=item Add support for accessibility features to ensure web pages are usable by all users.

=item Implement a backup and restore functionality for web pages to prevent data loss.

=item Add support for custom domains and subdomains for web pages.

=item Implement a security mechanism to protect web pages from unauthorized access and modifications.

=item Add support for user authentication and authorization for web page management.

=item Implement a logging mechanism to track changes and access to web pages.

=item Add support for webhooks to trigger actions based on web page events.

=item Implement a plugin system to allow third-party developers to extend web page functionality.

=item Add support for API endpoints to allow programmatic access to web page data.

=item Implement a content delivery network (CDN) integration for faster delivery of web page assets.

=item Add support for A/B testing and experimentation on web pages.

=item Implement a user-friendly interface for managing web pages, including drag-and-drop functionality.

=item Add support for custom metadata and SEO optimization for web pages.

=item Implement a notification system to alert users of changes or updates to web pages.

=item Add support for multilingual web pages to cater to a global audience.

=item Implement a content approval workflow for web pages to ensure quality and consistency.

=item Add support for custom URL structures and redirects for web pages.

=item Implement a feature to allow users to bookmark or favorite web pages for easy access.

=item Add support for custom CSS and JavaScript for web pages to allow for greater customization.

=item Implement a feature to allow users to subscribe to updates or changes on web pages.

=item Add support for content syndication and distribution for web pages.

=item Implement a feature to allow users to create and manage their own web pages within the application.

=item Add support for web page analytics and reporting to track user engagement and performance.

=item Implement a feature to allow users to export web pages as static HTML files.

=item Add support for web page archiving to preserve historical versions of web pages.

=item Implement a feature to allow users to import web pages from external sources.

=item Add support for web page collaboration, allowing multiple users to work on the same page simultaneously.

=item Implement a feature to allow users to create and manage web page templates for consistent design.

=item Add support for web page tagging and categorization for better organization.

=item Implement a feature to allow users to create and manage web page menus for easy navigation.

=item Add support for web page scheduling, allowing users to publish or unpublish pages at specific times.

=item Implement a feature to allow users to create and manage web page forms for user input.

=item Add support for web page comments and discussions to foster user engagement.

=item Implement a feature to allow users to create and manage web page galleries for images and media.

=item Add support for web page search functionality to help users find content easily.

=item Implement a feature to allow users to create and manage web page FAQs for common questions.

=item Add support for web page polls and surveys to gather user feedback.

=item Implement a feature to allow users to create and manage web page newsletters for email updates.

=item Add support for web page social sharing buttons to encourage content distribution.

=item Implement a feature to allow users to create and manage web page events and calendars.

=item Add support for web page user profiles to personalize content.

=back
