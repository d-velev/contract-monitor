import Vue from 'vue'
import App from './App.vue'
import "@aeternity/aepp-components/dist/aepp.components.css";
import "@aeternity/aepp-components/dist/aepp.fonts.css";

Vue.config.productionTip = false

new Vue({
  render: h => h(App),
}).$mount('#app')
