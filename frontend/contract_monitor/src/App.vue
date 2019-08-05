<template>
  <div id="app">
    <h1>Contract monitor</h1>
    <div>
      <ae-input-plain placeholder="Contract address" v-model="contractAddress" />
    </div>
    <div>
      <ae-button face="round" fill="primary" @click="submit(true)">Monitor</ae-button>
    </div>
    <div id="content">
      <div id="selectors">
        <ae-check v-model="chartDays" value="3" type="radio" @change="submit(false)">3 days</ae-check>
        <ae-check v-model="chartDays" value="7" type="radio" @change="submit(false)">7 days</ae-check>
        <ae-check v-model="chartDays" value="30" type="radio" @change="submit(false)">30 days (default)</ae-check>
      </div>
      <div id="calls-by-dates-chart" class="line-chart"><line-chart :chartData="callsByDates" :options="callsByDates.options"/></div>
      <div id="unique-users-by-dates-chart" class="line-chart"><line-chart :chartData="uniqueUsersByDates" :options="uniqueUsersByDates.options"/></div>
      <div id="amounts-by-dates-chart" class="line-chart"><line-chart :chartData="amountsByDates" :options="amountsByDates.options"/></div>
      <div>
        <h2>Events </h2>
        <table id="events">
          <thead>
            <tr>
              <th id="topics">
                Topics
              </th>
              <th>
                Data
              </th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="e in events" v-bind:key="e.data">
              <td>
                {{e.topics}}
              </td>
              <td>
                {{e.data}}
              </td>
            </tr>
          </tbody>
      </table>
    </div>
    </div>
  </div>
</template>

<script>
import { AeInputPlain, AeButton, AeCheck } from "@aeternity/aepp-components"

import LineChart from './LineChart.js'

let phoenix = require('phoenix-js')
let axios = require('axios');
let moment = require('moment')

export default {
  name: 'app',
  components: {
    AeInputPlain,
    AeButton,
    AeCheck,
    LineChart
  },
  data() {
    return {
      socket: null,
      channel: null,
      contractAddress: "",
      chartDays: 30,
      callsByDates: {},
      uniqueUsersByDates: {},
      uniqueUsersForToday: [],
      amountsByDates: {},
      events: []
    }
  },
  created: function(){
    this.socket = new phoenix.Socket('ws://localhost:4000/socket')
    this.channel = this.socket.channel('room:notifications')

    this.socket.connect()

    this.channel.join()

    let that = this;
    this.channel.on('new_call', function(msg) {
        that.callsByDates.datasets[0].data[that.callsByDates.datasets[0].data.length - 1]++
        var keys = that.callsByDates.labels;
        var values = that.callsByDates.datasets[0].data

        var result = {};
        keys.forEach((key, i) => result[key] = values[i]);
        that.fillData("callsByDates", result)

        if(!that.uniqueUsersForToday.includes(msg.tx.caller_id)) {
            that.uniqueUsersByDates.datasets[0].data[that.uniqueUsersByDates.datasets[0].data.length - 1]++;
            that.uniqueUsersForToday.push(msg.tx.caller_id);
        }

        values = that.uniqueUsersByDates.datasets[0].data
        keys.forEach((key, i) => result[key] = values[i]);
        that.fillData("uniqueUsersByDates", result)

        that.amountsByDates.datasets[0].data[that.amountsByDates.datasets[0].data.length - 1] += msg.tx.amount / 1000000000000000000
        values = that.amountsByDates.datasets[0].data
        keys.forEach((key, i) => result[key] = values[i]);
        that.fillData("amountsByDates", result)
      }
    )

    this.channel.on('new_event', function(events) {
      that.events = that.events.concat(events.events)
    })

  },
  destroyed: function() {
    this.socket.disconnect(()=>{}, 1000, 'disconnect');
  },
  methods: {
    newDate(days) {
      return moment().add(days, 'd');
    },
    submit(clearLogs) {
      if(this.contractAddress == "") return;

      document.getElementsByTagName('body')[0].style.overflow = "scroll"
      document.getElementById('content').style.visibility = "visible"
      let that = this
      axios.get(`http://localhost:4000/set-contract/${this.contractAddress}/edit`)
      axios.get(`https://testnet.mdw.aepps.com/middleware/contracts/transactions/address/${this.contractAddress}`)
      .then(async function(res){
        let block_hashes = []
        for(let i = 1; i < res.data.transactions.length; i++){
          block_hashes.push(res.data.transactions[i].block_hash)
        }

        let unique_hashes = block_hashes.filter( function(value, index, self) {
            return self.indexOf(value) === index;
        })

        let header_promises = []
        for(let i = 0; i < unique_hashes.length; i++){
          header_promises.push(axios.get(`https://sdk-testnet.aepps.com/v2/micro-blocks/hash/${unique_hashes[i]}/header`))
        }
        let block_timestamps = {}
        let calls_by_dates = {}
        let unique_users_by_dates = {}
        let unique_user_count_by_dates = {}
        let amounts_by_dates = {}
        Promise.all(header_promises).then(async function(headers){
          headers.forEach(function(el){
            block_timestamps[el.data.hash] = el.data.time
          })

          for (let i = that.chartDays - 1; i >= 0; i--) {
            let d = new Date();
            d.setDate(d.getDate() - i);
            let key = (d.getMonth() + 1) + '-' + d.getDate() + '-' + d.getFullYear()
            calls_by_dates[key] = 0
            unique_users_by_dates[key] = []
            unique_user_count_by_dates[key] = 0
            amounts_by_dates[key] = 0
          }

          let today = new Date();
          let n_days_back_date = new Date();
          n_days_back_date.setDate(n_days_back_date.getDate() - that.chartDays - 1)
          res.data.transactions.shift();
          let filtered_transactions = res.data.transactions.filter(function(value) {
            return block_timestamps[value.block_hash] >= n_days_back_date.getTime()
              && block_timestamps[value.block_hash] <= today.getTime();
          })

          for(let i = 0; i < filtered_transactions.length; i++){
            let d = new Date(block_timestamps[filtered_transactions[i].block_hash])
            let key = (d.getMonth() + 1) + '-' + d.getDate() + '-' + d.getFullYear()
            calls_by_dates[key]++

            if(!unique_users_by_dates[key].includes(filtered_transactions[i].tx.caller_id)) {
              unique_users_by_dates[key].push(filtered_transactions[i].tx.caller_id)
              unique_user_count_by_dates[key]++;
            }

            if(d.getMonth() == today.getMonth()
              && d.getDate() == today.getDate()
              && d.getFullYear() == today.getFullYear()
              && !that.uniqueUsersForToday.includes(filtered_transactions[i].tx.caller_id)) {
                that.uniqueUsersForToday.push(filtered_transactions[i].tx.caller_id)
              }

            amounts_by_dates[key] += filtered_transactions[i].tx.amount / 1000000000000000000
          }

          that.fillData("callsByDates", calls_by_dates)
          that.fillData("uniqueUsersByDates", unique_user_count_by_dates)
          that.fillData("amountsByDates", amounts_by_dates)
        })
      })

      if(clearLogs) {
        this.events = []
      }
    },
    fillData(key, data) {
      this[key] = {
        labels: Object.keys(data),
        datasets: [{
           data: Object.values(data),
           borderWidth: 2,
           borderColor: "#FF0D6A",
           fill: false,
           pointRadius: 0,
           hitRadius: 5
        }],
        options: {
          legend: {
            display: false
          },
          title: {
            display: true,
            text: this.keyToLabel(key)
          },
          scales: {
              yAxes: [{
                  ticks: {
                      beginAtZero: true
                  }
              }]
          }
        }
      }
    },
    keyToLabel(key) {
      let label = ""
      switch(key){
        case "callsByDates":
          label = "Calls"
          break;
        case "uniqueUsersByDates":
          label = "Unique users"
          break;
        case "amountsByDates":
          label = "Volume (æ tokens)"
          break;
      }

      return label;
    }
  }
}
</script>

<style>
body{
  overflow: hidden;
}
#content{
  visibility: hidden;
}
#events{
  margin: 0 auto 75px;
  width: 50%;
}
#selectors{
  margin: 10px 0 10px;
}
#topics{
  width: 50%;
}
.ae-input-plain{
  margin-bottom: 20px;
  text-align: center;
  width: 40% !important;

}
.ae-button{
  margin-bottom: 20px;
}
.ae-check-button {
  padding-left: 2.5rem !important;
  padding-right: 3rem !important;
}
.line-chart{
  width: 33%;
  float: left;
  margin: 0 auto;
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
