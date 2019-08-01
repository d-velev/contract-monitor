<template>
  <div id="app">
    <ae-input-plain placeholder="Contract address" v-model="contractAddress" />
    <ae-button face="round" fill="primary" @click="submit">Hello World</ae-button>
    <div id="chart"><line-chart :chart-data="datacollection"></line-chart></div>
  </div>
</template>

<script>
import { AeInputPlain, AeButton } from "@aeternity/aepp-components"

import LineChart from './LineChart.js'

let phoenix = require('phoenix-js')
let axios = require('axios');

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
    submit() {
      axios.get(`http://localhost:4000/set-contract/${this.contractAddress}/edit`)
      axios.get(`https://testnet.mdw.aepps.com/middleware/contracts/transactions/address/${this.contractAddress}`).then(function(res){
        res.data
      })
    },
    fillData () {
        this.datacollection = {
          labels: [1,2,3],
          datasets: [{data: [1,3,2]}]
        }
      }
  }
}
</script>

<style>
#chart{
  width: 400px;
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
