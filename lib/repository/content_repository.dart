import '../data/network/api_network_service.dart';
import '../data/network/base_api_service.dart';
import '../models/content_model.dart';
import '../res/appUrl.dart';

class ContentRepository {
  final BaseApiService _apiService = NetworkApiService();

  Future<ContentModel> getContent() async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.getContent);
      return ContentModel.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Content>> getMovies() async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.getMovies);
      if (response['success'] == true) {
        List<Content> movies = (response['movies'] as List).map((e) {
          final content = Content.fromJson(e);
          content.type = 'movie';
          return content;
        }).toList();
        return movies;
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<Content?> getMovieById(String id) async {
    try {
      dynamic response = await _apiService.getApi('${AppUrl.getMovies}/id/$id');
      if (response['success'] == true) {
        final content = Content.fromJson(response['movie']);
        content.type = 'movie';
        return content;
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Content>> getTvShows() async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.getTvShows);
      if (response['success'] == true) {
        List<Content> tvShows = (response['dramas'] as List).map((e) {
          final content = Content.fromJson(e);
          content.type = 'tvShow';
          return content;
        }).toList();
        return tvShows;
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Content>> getShortFilms() async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.getShortFilms);
      if (response['success'] == true) {
        List<Content> shortFilms = (response['shortFilms'] as List).map((e) {
          final content = Content.fromJson(e);
          content.type = 'shortFilm';
          return content;
        }).toList();
        return shortFilms;
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Content>> getTvShowEpisodes(String tvShowId) async {
    try {
      dynamic response = await _apiService.getApi(AppUrl.getTvShowEpisodes(tvShowId));
      if (response['success'] == true) {
        List<Content> episodes = (response['episodes'] as List).map((e) {
          final content = Content.fromJson(e);
          content.type = 'episode';
          return content;
        }).toList();
        return episodes;
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }
}
