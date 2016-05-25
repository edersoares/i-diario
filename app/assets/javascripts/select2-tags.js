$(function() {
  'use strict';

  _.each($('.select2-tags'), function(element) {
    $(element).select2({
      tags: true,
      tokenSeparators: [','],
      createSearchChoice: function (term) {
          return {
              id: $.trim(term),
              text: $.trim(term) + ' (Novo conteúdo)'
          };
      },
      data: $(element).data('elements')
    });
  });

  _.each($('.select2-tags-ajax'), function(element) {

    $(element).select2({
      tags: true,
      tokenSeparators: [','],
      createSearchChoice: function (term) {
          return {
              id: $.trim(term),
              text: $.trim(term) + ' (Novo conteúdo)'
          };
      },
      minimumInputLength: 3,
      formatInputTooShort: function () {
          return "Digite no mínimo 3 caractereres";
      },
      ajax: {
        dataType: "json",
        url: $(element).data('url'),
        delay: 250,
        data: function (term, page) {
          var query = {
            filter: {
              by_description: term,
              page: page,
              per: 10
            }
          }

          return query;
        },
        results: function (data, page) {
          page = page || 1;
          var results = []
          $.each(data.contents, function(k, content){
            results.push({
              id: content.description,
              text: content.description
            })
          });

          return {
            results: results
          };
        }
      }
    }).select2('data', $(element).data('data'));

  });
});