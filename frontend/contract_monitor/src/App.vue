<template>
  <div id="app">
    <ae-input-plain placeholder="Contract address" v-model="contractAddress" />
    <ae-button face="round" fill="primary" @click="submit">Hello World</ae-button>
    <div id="chart"><line-chart :chartData="datacollection"/></div>
  </div>
</template>

<script>
import { AeInputPlain, AeButton } from "@aeternity/aepp-components"

import LineChart from './LineChart.js'

let phoenix = require('phoenix-js')
let axios = require('axios');
let moment = require('moment')

export default {
  name: 'app',
  components: {
    AeInputPlain,
    AeButton,
    LineChart
  },
  data() {
    return {
      contractAddress: "",
      datacollection: null
    }
  },
  mounted: function() {
      this.fillData()
    },
  created: function(){
    let socket = new phoenix.Socket('ws://localhost:4000/socket')
    let channel = socket.channel('room:notifications')

    socket.connect()

    channel.join()
    .receive('ok', ({messages}) => console.log('Successful join', messages))
    .receive('error', ({reason}) => console.log('Failed join', reason))
    .receive('timeout', () => console.log('Timeout when joining'))

    channel.on('new_call', msg => console.log(msg))

  },
  methods: {
    newDate(days) {
      return moment().add(days, 'd');
    },
    submit() {
      axios.get(`http://localhost:4000/set-contract/${this.contractAddress}/edit`)
      axios.get(`https://testnet.mdw.aepps.com/middleware/contracts/transactions/address/${this.contractAddress}`).then(function(res){
        let data = {}
        for(i = 0; i < res.data.transactions.length; i++){
          
        }
        this.fillData(res.data)
      })
    },
    fillData (data) {
      this.datacollection = {
        labels: [this.newDate(1),this.newDate(6),this.newDate(7)],
        datasets: [{
           data: [1,2,3],
           label: "bla",
           borderWidth: 2,
           borderColor: "#3e95cd",
           fill: false,
           pointRadius: 0
        }]
      }
    }
  }
}
</script>

<style>
#chart{
  width: 50%;
}
#app {
  font-family: 'Avenir', Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-align: center;
  color: #2c3e50;
  margin-top: 60px;
}
</style>
