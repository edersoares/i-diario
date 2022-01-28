$(document).ready(function() {
  'use strict';

  let flashMessages = new FlashMessages(),
      redirect_link_report_card = Routes.teacher_report_cards_pt_br_path,
      redirect_link_conceptual_exams = Routes.conceptual_exams_pt_br_path,
      redirect_link_descriptive_exams = Routes.conceptual_exams_pt_br_path,
      message = `O Registros de avaliações numéricas apresentará somente as notas lançadas nos diários de avaliação e recuperações numéricas. Para conferência de notas conceituais e/ou descritivas acessar, respectivamente, o <a href="${redirect_link_report_card}"><b>Boletim do professor</b></a> ou as telas de <a href="${redirect_link_conceptual_exams}"><b>Diário de avaliações conceituais</b></a> e <a href="${redirect_link_descriptive_exams}"><b>Avaliações descritivas</b></a>.`;

  flashMessages.info(message);
});
