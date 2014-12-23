'use strict';

var _ = require('lodash');

/**@ngInject*/
var HeaderController = function($rootScope, $scope, $sce, $modal, CartService, currentUser, alerts) {

  this.$modal = $modal;
  this.CartService = CartService;
  this.alerts = alerts;
  this.currentUser = currentUser;

  // @todo This is in the wrong format, does not match the problem-alerts.html partial format.
  angular.forEach(this.alerts, function(item) {
    item.trustedHtml = $sce.trustAsHtml(item.text);
  });

  this.isModalOpen = false;
};

HeaderController.resolve = {

};

HeaderController.prototype = {

  /**
   * Move this to a state.
   */
  cartModal: function () {

      if (this.isModalOpen) {
        return;
      }

      this.isModalOpen = true;

      var modalInstance = this.$modal.open({
        templateUrl: 'cart/cart-modal.html',
        controller: 'CartController as cartCtrl',
        size: 'lg'
      });

      var setModalStatusClosed = _.bind(function() {
        this.isModalOpen = false;
      }, this);

      modalInstance.result.finally(setModalStatusClosed, setModalStatusClosed);
    },

  cartCount: function() {
    return this.CartService.getCount();
  }
};

module.exports = HeaderController;



